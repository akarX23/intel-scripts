from datasets import load_dataset
from PIL import Image
from io import BytesIO
import numpy as np

def convert_to_image(image_data):
    """
    Convert dataset image field to a PIL.Image.Image object.
    Handles byte streams and lists.
    """
    if isinstance(image_data, Image.Image):
        return image_data
    elif isinstance(image_data, dict) and "bytes" in image_data:
        return Image.open(BytesIO(image_data["bytes"]))
    elif isinstance(image_data, list):
        # Convert list of lists to numpy array, then to PIL
        return Image.fromarray(np.array(image_data, dtype=np.uint8))
    else:
        raise ValueError("Unsupported image format:", type(image_data))

def resize_image_safe(image_data, size=(480, 480)):
    try:
        image = convert_to_image(image_data)
        print(f"Original size: {image.size}")
        return image.resize(size, Image.Resampling.LANCZOS)
    except Exception as e:
        print(f"Failed to resize image: {e}")
        return image_data  # Return original if failed

def resize_dataset_images(dataset_name, split="train", size=(480, 480)):
    dataset = load_dataset(dataset_name, split=split)

    resized_dataset = dataset.map(
        lambda example: {"images": [resize_image_safe(example["images"][0], size)]},
        desc="Resizing images",
        num_proc=256
    )

    return resized_dataset

resized_ds = resize_dataset_images("lmarena-ai/VisionArena-Chat", split="train")
resized_ds.save_to_disk("resized_vision_dataset")
