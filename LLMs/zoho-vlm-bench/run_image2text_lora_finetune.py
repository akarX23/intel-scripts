from torchvision.io import read_image
from PIL import Image

import logging
import os
import random
import sys
from dataclasses import dataclass, field
from typing import List, Optional

import Levenshtein
import torch
import transformers
from datasets import load_dataset
from peft import LoraConfig, get_peft_model
from transformers import (
    AutoConfig,
    AutoModelForVision2Seq,
    AutoProcessor,
    HfArgumentParser,
)
from transformers.trainer_utils import is_main_process

from optimum.habana import GaudiConfig, GaudiTrainer, GaudiTrainingArguments


try:
    from optimum.habana.utils import check_optimum_habana_min_version
except ImportError:

    def check_optimum_habana_min_version(*a, **b):
        return ()


os.environ["WANDB_DISABLED"] = "true"
logger = logging.getLogger(__name__)

# Will error if the minimal version of Optimum Habana is not installed. Remove at your own risks.
check_optimum_habana_min_version("1.17.0")


def normalized_levenshtein(s1, s2):
    len_s1, len_s2 = len(s1), len(s2)
    distance = Levenshtein.distance(s1, s2)
    return distance / max(len_s1, len_s2)


def similarity_score(a_ij, o_q_i, tau=0.5):
    nl = normalized_levenshtein(a_ij, o_q_i)
    return 1 - nl if nl < tau else 0


def average_normalized_levenshtein_similarity(ground_truth, predicted_answers):
    assert len(ground_truth) == len(predicted_answers), "Length of ground_truth and predicted_answers must match."

    N = len(ground_truth)
    total_score = 0

    for i in range(N):
        a_i = ground_truth[i]
        o_q_i = predicted_answers[i]
        if o_q_i == "":
            print("Warning: Skipped an empty prediction.")
            max_score = 0
        else:
            max_score = max(similarity_score(a_ij, o_q_i) for a_ij in a_i)

        total_score += max_score

    return total_score / N
    
    
@dataclass
class ModelArguments:
    """
    Arguments pertaining to which model/config/processor we are going to fine-tune, or train from scratch.
    """

    model_name_or_path: Optional[str] = field(
        default=None,
        metadata={
            "help": "The model checkpoint for weights initialization."
            "Don't set if you want to train a model from scratch."
        },
    )
    config_name: Optional[str] = field(
        default=None,
        metadata={"help": "Pretrained config name or path if not the same as model_name"},
    )
    cache_dir: Optional[str] = field(
        default=None,
        metadata={"help": "Where do you want to store the pretrained models downloaded from huggingface.co"},
    )
    token: Optional[str] = field(
        default=None,
        metadata={"help": "auth token for private models"},
    )
    use_fast_tokenizer: bool = field(
        default=True,
        metadata={"help": "Whether to use one of the fast tokenizer (backed by the tokenizers library) or not."},
    )
    model_revision: str = field(
        default="main",
        metadata={"help": "The specific model version to use (can be a branch name, tag name or commit id)."},
    )
    trust_remote_code: bool = field(
        default=False,
        metadata={
            "help": (
                "Whether to trust the execution of code from datasets/models defined on the Hub."
                " This option should only be set to `True` for repositories you trust and in which you have read the"
                " code, as it will execute code present on the Hub on your local machine."
            )
        },
    )
    use_cache: bool = field(
        default=True,
        metadata={
            "help": (
                "Whether or not the model should return the last key/values attentions (not used by all models)."
                "Only relevant if `config.is_decoder=True`."
            )
        },
    )
    
    low_cpu_mem_usage: bool = field(
        default=False,
        metadata={
            "help": (
                "It is an option to create the model as an empty shell, then only materialize its parameters when the pretrained weights are loaded."
                "When set to True, it will benefit LLM loading time and RAM consumption."
            )
        },
    )
    load_meta_device: bool = field(
        default=False,
        metadata={
            "help": (
                "It is an option to load the model to the device instead of the host, so it can reduce the host RAM usage."
                "https://huggingface.co/blog/accelerate-large-models"
            )
        },
    )
    do_image_splitting: bool = field(default=False, metadata={"help": "Whether to do image split during finetune."})


dataclass
class DataArguments:
    """
    Arguments pertaining to what data we are going to input our model for training and eval.
    """

    dataset_name: Optional[str] = field(
        default=None,
        metadata={"help": "The name of the dataset to use (via the datasets library)."},
    )
    dataset_config_name: Optional[str] = field(
        default=None,
        metadata={"help": "The configuration name of the dataset to use (via the datasets library)."},
    )
    max_seq_length: Optional[int] = field(
        default=512,
        metadata={
            "help": "The maximum total input sequence length after tokenization. Sequences longer "
            "than this will be truncated."
        },
    )
    overwrite_cache: bool = field(
        default=False,
        metadata={"help": "Overwrite the cached preprocessed datasets or not."},
    )
    max_train_samples: Optional[int] = field(
        default=None,
        metadata={
            "help": "For debugging purposes or quicker training, truncate the number of training examples to this "
            "value if set."
        },
    )
    max_eval_samples: Optional[int] = field(
        default=None,
        metadata={
            "help": "For debugging purposes or quicker training, truncate the number of evaluation examples to this "
            "value if set."
        },
    )
    dataset_seed: int = field(
        default=42,
        metadata={
            "help": "Seed to use in dataset processing, different seeds might yield different datasets. This seed and the seed in training arguments are not related"
        },
    )
    save_last_ckpt: bool = field(
        default=True, metadata={"help": "Whether to save checkpoint at the end of the training."}
    )
    input_column_names: List[str] = field(
        default_factory=lambda: None,
        metadata={
            "help": "Name of the column in the dataset that optionally provides context or input for the task. By "
            "default, 'image,query' columns are used"
        },
    )
    output_column_names: List[str] = field(
        default_factory=lambda: None,
        metadata={
            "help": "Name of the column in the dataset with the answer to the instruction. By default, the "
            "'answers' column is used"
        },
    )

@dataclass
class FinetuneArguments:
    """
    Arguments of finetune we are going to apply on the model.
    """

    lora_rank: int = field(
        default=8,
        metadata={"help": "Rank parameter in the LoRA method."},
    )
    lora_alpha: int = field(
        default=8,
        metadata={"help": "Alpha parameter in the LoRA method."},
    )
    lora_dropout: float = field(
        default=0.1,
        metadata={"help": "Dropout parameter in the LoRA method."},
    )
    lora_target_modules: str = field(
        default=None,
        metadata={"help": "Target modules for the LoRA/AdaLoRA method."},
    )

class MyDataCollator:
    def __init__(self, processor, max_seq_length, image_token_id):
        self.processor = processor
        self.image_token_id = image_token_id
        self.max_seq_length = max_seq_length

    def __call__(self, examples):
        texts = []
        images = []
        keys = list(examples[0].keys())
        if not all(key in ["image_name", "query", "answer"] for key in keys):
            raise ValueError("Unsupported dataset format")
        for example in examples:
            print(example)
            # image = example["image_name"]
            image = read_image(example["image_name"])
            question = example["query"]
            answer = example["answer"]
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Answer briefly."},
                        {"type": "image"},
                        {"type": "text", "text": question},
                    ],
                },
                {"role": "assistant", "content": [{"type": "text", "text": answer}]},
            ]
            text = self.processor.apply_chat_template(messages, add_generation_prompt=False)
            texts.append(text.strip())
            images.append([image])

        batch = self.processor(
            text=texts,
            images=images,
            return_tensors="pt",
            padding="max_length",
            truncation=True,
            max_length=self.max_seq_length,
        )

        labels = batch["input_ids"].clone()
        labels[labels == self.processor.tokenizer.pad_token_id] = -100
        labels[labels == self.image_token_id] = -100
        batch["labels"] = labels

        return batch

class LLavaDataCollator:
    def __init__(self, processor, max_seq_length):
        self.processor = processor

        num_image_tokens = (self.processor.image_processor.crop_size["height"] // self.processor.patch_size) * (
            self.processor.image_processor.crop_size["width"] // self.processor.patch_size
        ) + 1
        if self.processor.vision_feature_select_strategy == "default":
            num_image_tokens -= 1

        # text length + image length
        self.max_seq_length = max_seq_length + num_image_tokens

    def __call__(self, examples):
        texts = []
        images = []

        keys = list(examples[0].keys())
        if not all(key in ["image", "query", "answers"] for key in keys):
            raise ValueError("Unsupported dataset format")
        for example in examples:
            image = example["image"]
            question = example["query"]["en"]
            answer = random.choice(example["answers"])
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Answer briefly."},
                        {"type": "image"},
                        {"type": "text", "text": question},
                    ],
                },
                {"role": "assistant", "content": [{"type": "text", "text": answer}]},
            ]
            text = self.processor.apply_chat_template(messages, add_generation_prompt=False)
            texts.append(text.strip())
            images.append(image)

        batch = self.processor(
            images, texts, return_tensors="pt", padding="max_length", truncation=True, max_length=self.max_seq_length
        )

        labels = batch["input_ids"].clone()
        if self.processor.tokenizer.pad_token_id is not None:
            labels[labels == self.processor.tokenizer.pad_token_id] = -100
        batch["labels"] = labels

        return batch

def eval(processor, model, dataset, batch_size, use_lazy_mode, use_hpu_graphs, max_seq_length, model_type, data_args):
    from tqdm import tqdm

    answers_unique = []
    generated_texts_unique = []

    for i in tqdm(range(0, len(dataset), batch_size)):
        examples = dataset[i : i + batch_size]

        # answers_unique.extend(examples["answers"])

        # Debug part to confirm keys
        print(f"Batch keys: {examples.keys()}") # Added by me 

        answers_unique.extend(examples[data_args.output_column_names[0]]) # Added by me 

        texts = []
        for q in examples["query"]:
            messages = [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Answer briefly."},
                        {"type": "image"},
                        # {"type": "text", "text": q["en"]},


                        {"type": "text", "text": q}, # Added by me 
                    ],
                }
            ]
            text = processor.apply_chat_template(messages, add_generation_prompt=True)
            texts.append(text.strip())

        if model_type is not None and model_type == "llava":
            images = []
            for im in examples["image"]:
                images.append(im)

            inputs = processor(
                images,
                texts,
                return_tensors="pt",
                padding=True,
                truncation=False,
                max_length=max_seq_length,
                padding_side="left",
            )
        else:
            # images = [[im] for im in examples["image"]]

            # Because our batch has keys "image_name" not "image"
            images = [[Image.open(im).convert("RGB")] for im in examples["image_name"]] # Added by me 
            # images = [[im] for im in examples["image_name"]] # Added by me 

            inputs = processor(
                text=texts,
                images=images,
                return_tensors="pt",
                padding="max_length",
                truncation=True,
                max_length=max_seq_length,
            )
        inputs = {k: v.to("hpu") for k, v in inputs.items()}
        generated_ids = model.generate(
            **inputs, max_new_tokens=64, ignore_eos=False, lazy_mode=use_lazy_mode, hpu_graphs=use_hpu_graphs
        )
        generated_texts = processor.batch_decode(
            generated_ids[:, inputs["input_ids"].size(1) :], skip_special_tokens=True
        )
        generated_texts_unique.extend(generated_texts)
    generated_texts_unique = [g.strip().strip(".") for g in generated_texts_unique]

    #Added by me 
    print("/n===== Debug Evaluation output=====")
    for idx, (gt,pred) in enumerate(zip(answers_unique,generated_texts_unique)):
        print(f"[Example {idx}]")
        print(f" Ground Truth: {gt}")
        print(f" Model Prediction: {pred}")
        print("=============================")


    anls = average_normalized_levenshtein_similarity(
        ground_truth=answers_unique,
        predicted_answers=generated_texts_unique,
    )

    print(f"\nFinal ANLS Score: {anls:.4f}")

    return anls

def find_all_linear_names(model):
    cls = torch.nn.Linear
    lora_module_names = set()
    multimodal_keywords = ["mm_projector", "vision_tower", "vision_resampler"]
    for name, module in model.named_modules():
        if any(mm_keyword in name for mm_keyword in multimodal_keywords):
            continue
        if isinstance(module, cls):
            names = name.split(".")
            lora_module_names.add(names[0] if len(names) == 1 else names[-1])

    if "lm_head" in lora_module_names:  # needed for 16-bit
        lora_module_names.remove("lm_head")
    return list(lora_module_names)


def main():
    parser = HfArgumentParser((ModelArguments, DataArguments, GaudiTrainingArguments, FinetuneArguments))
    if len(sys.argv) == 2 and sys.argv[1].endswith(".json"):
        # If we pass only one argument to the script and it's the path to a json file,
        # let's parse it to get our arguments.
        model_args, data_args, training_args, finetune_args = parser.parse_json_file(
            json_file=os.path.abspath(sys.argv[1])
        )
    else:
        (
            model_args,
            data_args,
            training_args,
            finetune_args,
        ) = parser.parse_args_into_dataclasses()

    # Setup logging
    logging.basicConfig(
        format="%(asctime)s - %(levelname)s - %(name)s -   %(message)s",
        datefmt="%m/%d/%Y %H:%M:%S",
        handlers=[logging.StreamHandler(sys.stdout)],
    )
    logger.setLevel(logging.INFO if is_main_process(training_args.local_rank) else logging.WARN)

    if is_main_process(training_args.local_rank):
        transformers.utils.logging.set_verbosity_info()
        transformers.utils.logging.enable_default_handler()
        transformers.utils.logging.enable_explicit_format()

    processor = AutoProcessor.from_pretrained(
        model_args.model_name_or_path,
        do_image_splitting=model_args.do_image_splitting,
        padding_side="right",
    )

    config_kwargs = {
        "cache_dir": model_args.cache_dir,
        "revision": model_args.model_revision,
        "trust_remote_code": True if model_args.trust_remote_code else None,
        "use_cache": False if training_args.gradient_checkpointing else model_args.use_cache,
        "token": model_args.token,
    }
    if model_args.config_name:
        config = AutoConfig.from_pretrained(model_args.config_name, **config_kwargs)
    elif model_args.model_name_or_path:
        config = AutoConfig.from_pretrained(model_args.model_name_or_path, **config_kwargs)
    else:
        raise ValueError("Please provide value for model_name_or_path or config_name.")

    if config.model_type == "llava":
        setattr(processor, "patch_size", config.vision_config.patch_size)
        setattr(processor, "vision_feature_select_strategy", config.vision_feature_select_strategy)
    else:
        setattr(processor.image_processor, "pad_to_longest_edge", True)


# Load model
    if model_args.model_name_or_path:
        model_dtype = torch.bfloat16 if training_args.bf16 else None
        model = AutoModelForVision2Seq.from_pretrained(
            model_args.model_name_or_path,
            from_tf=bool(".ckpt" in model_args.model_name_or_path),
            config=config,
            cache_dir=model_args.cache_dir,
            revision=model_args.model_revision,
            trust_remote_code=True if model_args.trust_remote_code else None,
            torch_dtype=model_dtype,
            low_cpu_mem_usage=model_args.low_cpu_mem_usage,
            device_map=training_args.device.type if model_args.load_meta_device else None,
            token=model_args.token,
        )
    else:
        raise ValueError("Must provide model_name_or_path to load a pretrained CausalLM model.")

    if finetune_args.lora_target_modules is None:
        target_modules = find_all_linear_names(model)
    else:
        target_modules = finetune_args.lora_target_modules

    lora_config = LoraConfig(
        r=finetune_args.lora_rank,
        lora_alpha=finetune_args.lora_alpha,
        lora_dropout=finetune_args.lora_dropout,
        target_modules=target_modules,
        init_lora_weights="gaussian",
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    train_dataset = load_dataset(
        "arrow",
        data_files={'train': f"{data_args.dataset_name}/train/data-00000-of-00001.arrow"},
        # data_args.dataset_name,
        # data_args.dataset_config_name,
        cache_dir=model_args.cache_dir,
        token=model_args.token,
        trust_remote_code=model_args.trust_remote_code,
        split="train",
    )

    train_dataset = train_dataset.remove_columns(
        [
            col
            for col in train_dataset.column_names
            if col not in (data_args.input_column_names + data_args.output_column_names)
        ]
    )

    eval_dataset = load_dataset(
        "arrow",
        data_files={'test': f"{data_args.dataset_name}/test/data-00000-of-00001.arrow"},
        # data_args.dataset_name,
        # data_args.dataset_config_name,
        cache_dir=model_args.cache_dir,
        token=model_args.token,
        trust_remote_code=model_args.trust_remote_code,
        split="test",
    )

    eval_dataset = eval_dataset.remove_columns(
        [
            col
            for col in eval_dataset.column_names
            if col not in (data_args.input_column_names + data_args.output_column_names)
        ]
    )


    if config.model_type == "llava":
            data_collator = LLavaDataCollator(processor, max_seq_length=data_args.max_seq_length)
    else:
        if hasattr(config, "image_token_id"):
            # idefics
            image_token_id = config.image_token_id
        elif hasattr(config, "image_token_index"):
            # mllama
            image_token_id = config.image_token_index
        else:
            raise ValueError("Please provide value for image_token_id")

        data_collator = MyDataCollator(
            processor, max_seq_length=data_args.max_seq_length, image_token_id=image_token_id
        )

    gaudi_config = GaudiConfig()
    gaudi_config.use_fused_adam = True
    gaudi_config.use_fused_clip_norm = True

    trainer = GaudiTrainer(
        model=model,
        args=training_args,
        gaudi_config=gaudi_config,
        data_collator=data_collator,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
    )

    if training_args.do_train:
        train_result = trainer.train()
        trainer.save_model()
        metrics = train_result.metrics
        trainer.log_metrics("train", metrics)
        trainer.save_metrics("train", metrics)

    if is_main_process(training_args.local_rank):
        processor.tokenizer.padding_side = "left"

        example = eval_dataset[15]
        model.eval()
        model = model.merge_and_unload()
        if model_dtype == torch.bfloat16:
            model = model.to(torch.bfloat16)


# image = example["image_name"]
        # Added by me
    image_path = example["image_name"]
    image = Image.open(image_path).convert("RGB")
    # till here

    query = example["query"]

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Answer briefly."},
                {"type": "image"},
                {"type": "text", "text": query},
            ],
        }
    ]
    text = processor.apply_chat_template(messages, add_generation_prompt=True)

    if config.model_type == "llava":
        inputs = processor(
            [image],
            [text.strip()],
            return_tensors="pt",
            padding=True,
            truncation=False,
            max_length=data_args.max_seq_length,
            padding_side="left",
        )
    else:
        inputs = processor(
            text=[text.strip()],
            images=[image],
            return_tensors="pt",
            padding="max_length",
            truncation=True,
            max_length=data_args.max_seq_length,
        )
    inputs = {k: v.to("hpu") for k, v in inputs.items()}
    generated_ids = model.generate(
        **inputs,
        max_new_tokens=64,
        ignore_eos=False,
        lazy_mode=training_args.use_lazy_mode,
        hpu_graphs=training_args.use_hpu_graphs_for_inference,
    )
    generated_texts = processor.batch_decode(
        generated_ids[:, inputs["input_ids"].size(1) :], skip_special_tokens=True
    )
    logger.info(f"generated: {generated_texts}")
    if training_args.do_eval:
        if training_args.use_hpu_graphs_for_inference:
            from habana_frameworks.torch.hpu import wrap_in_hpu_graph

            model = wrap_in_hpu_graph(model)


    anls = eval(
                    processor=processor,
                    model=model,
                    dataset=eval_dataset,
                    batch_size=training_args.per_device_eval_batch_size,
                    use_lazy_mode=training_args.use_lazy_mode,
                    use_hpu_graphs=training_args.use_hpu_graphs_for_inference,
                    max_seq_length=data_args.max_seq_length,
                    model_type=config.model_type,
                    data_args=data_args, # Added by me 
                )
    eval_metrics = {"eval_accuracy": anls}
    trainer.log_metrics("eval", eval_metrics)
    trainer.save_metrics("eval", eval_metrics)


if __name__ == "__main__":
    main()
