class ISClipLength:
    PRESETS = {
        "5 sec - 124 frames": 124,
        "10 sec - 244 frames": 244,
        "15 sec - 364 frames": 364,
    }

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "clip_length": (
                    list(cls.PRESETS.keys()),
                    {"default": "5 sec - 124 frames"},
                ),
            }
        }

    RETURN_TYPES = ("INT", "FLOAT", "STRING")
    RETURN_NAMES = ("frames", "seconds", "label")

    FUNCTION = "select"
    CATEGORY = "IS/config"

    def select(self, clip_length):
        frames = self.PRESETS[clip_length]
        seconds = frames / 24.0

        print(
            f"[IS Clip Length] {clip_length}: "
            f"{frames} frames ({seconds:.2f} sec @ 24 fps)",
            flush=True,
        )

        return (
            frames,
            seconds,
            clip_length,
        )


NODE_CLASS_MAPPINGS = {
    "ISClipLength": ISClipLength,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "ISClipLength": "IS Clip Length",
}
