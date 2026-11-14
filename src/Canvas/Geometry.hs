-- | Points, sizes, rectangles and colours. Lengths are logical pixels, the
-- units the layout works in; the renderer multiplies them by the window's
-- pixel density.
module Canvas.Geometry
  ( Point (..)
  , Size (..)
  , Rect (..)
  , Color (..)
  , rgb
  , contains
  , inset
  , outset
  ) where

import Relude

data Point = Point
  { pointX :: !Double
  , pointY :: !Double
  }
  deriving stock (Eq, Show)

data Size = Size
  { sizeW :: !Double
  , sizeH :: !Double
  }
  deriving stock (Eq, Show)

data Rect = Rect
  { rectX :: !Double
  , rectY :: !Double
  , rectW :: !Double
  , rectH :: !Double
  }
  deriving stock (Eq, Show)

data Color = Color
  { colorR :: !Word8
  , colorG :: !Word8
  , colorB :: !Word8
  , colorA :: !Word8
  }
  deriving stock (Eq, Ord, Show)

-- | An opaque colour.
rgb :: Word8 -> Word8 -> Word8 -> Color
rgb r g b = Color r g b 255

contains :: Rect -> Point -> Bool
contains (Rect x y w h) (Point px py) = px >= x && px < x + w && py >= y && py < y + h

-- | The rectangle with this much taken off every side.
inset :: Double -> Rect -> Rect
inset d (Rect x y w h) = Rect (x + d) (y + d) (max 0 (w - 2 * d)) (max 0 (h - 2 * d))

-- | The rectangle with this much added to every side.
outset :: Double -> Rect -> Rect
outset d (Rect x y w h) = Rect (x - d) (y - d) (w + 2 * d) (h + 2 * d)
