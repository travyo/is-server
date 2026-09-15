
import os

import shutil

import tempfile

import numpy as np

from PIL import Image

import folder_paths

class ISSaveContinuationFrame:

    """

    Saves an IMAGE batch to a fixed PNG in ComfyUI/input.

    The final image in the batch is used, although our workflow should

    normally send a single frame into this node.

    """

    @classmethod

    def INPUT_TYPES(cls):

        return {

            "required": {

                "images": ("IMAGE",),

            }

        }

    RETURN_TYPES = ("IMAGE",)

    RETURN_NAMES = ("images",)

    FUNCTION = "save"

    OUTPUT_NODE = True

    CATEGORY = "IS/continuation"

    def save(self, images):

        input_dir = folder_paths.get_input_directory()

        os.makedirs(input_dir, exist_ok=True)

        final_path = os.path.join(

            input_dir,

            "is_continuation.png",

        )

        # Use final image from batch.

        image = images[-1]

        image = (

            image.detach()

            .cpu()

            .numpy()

        )

        image = np.clip(

            image * 255.0,

            0,

            255,

        ).astype(np.uint8)

        pil_image = Image.fromarray(image)

        # Atomic replacement so another run never sees a half-written PNG.

        fd, temp_path = tempfile.mkstemp(

            suffix=".png",

            dir=input_dir,

        )

        os.close(fd)

        try:

            pil_image.save(

                temp_path,

                format="PNG",

            )

            os.replace(

                temp_path,

                final_path,

            )

        finally:

            if os.path.exists(temp_path):

                os.unlink(temp_path)

        print(

            f"[IS Continuation] Saved continuation frame: {final_path}",

            flush=True,

        )

        return (images,)

NODE_CLASS_MAPPINGS = {

    "ISSaveContinuationFrame": ISSaveContinuationFrame,

}

NODE_DISPLAY_NAME_MAPPINGS = {

    "ISSaveContinuationFrame": "IS Save Continuation Frame",

}

