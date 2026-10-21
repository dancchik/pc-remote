"""Capture the screen as PNG bytes."""

import mss
import mss.tools


def take_screenshot() -> bytes:
    with mss.MSS() as sct:
        # monitors[0] is a virtual monitor covering all physical screens together.
        image = sct.grab(sct.monitors[0])
        return mss.tools.to_png(image.rgb, image.size)
