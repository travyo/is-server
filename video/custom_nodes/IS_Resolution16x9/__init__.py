class ISResolution16x9:
    """
    16:9-ish H3 resolution presets using dimensions aligned to multiples of 32.
    """

    PRESETS = {
        "0.2 MP - 608x352 - FAST": (608, 352),
        "0.3 MP - 736x416": (736, 416),
        "0.4 MP - 864x480": (864, 480),
        "0.5 MP - 960x544": (960, 544),
        "0.6 MP - 1056x608": (1056, 608),
        "0.7 MP - 1152x640": (1152, 640),
        "0.8 MP - 1216x672": (1216, 672),
        "0.9 MP - 1280x736": (1280, 736),
        "0.98 MP - 1344x768 - QUALITY": (1344, 768),
    }

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "resolution": (
                    list(cls.PRESETS.keys()),
                    {"default": "0.2 MP - 608x352 - FAST"},
                ),
            }
        }

    RETURN_TYPES = ("INT", "INT", "FLOAT", "STRING")
    RETURN_NAMES = ("width", "height", "megapixels", "label")

    FUNCTION = "select"
    CATEGORY = "IS/config"

    def select(self, resolution):
        width, height = self.PRESETS[resolution]
        megapixels = (width * height) / 1_000_000.0

        print(
            f"[IS Resolution 16:9] {resolution}: "
            f"{width}x{height} ({megapixels:.3f} MP)",
            flush=True,
        )

        return (
            width,
            height,
            megapixels,
            resolution,
        )


NODE_CLASS_MAPPINGS = {
    "ISResolution16x9": ISResolution16x9,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "ISResolution16x9": "IS 16:9 Resolution Switcher",
}
