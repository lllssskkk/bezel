module Canvas.Input ( Input (..)
, Key (..)
, Modifiers (..)
, noModifiers) where

import Relude
import Canvas.Geometry
import qualified Data.Text as T


data Input
    = PointerPressed Point
    | KeyPressed Modifiers Key
    | TextTyped T.Text
    | WindowResized Size

 -- | The keys the editor reacts to; any other key never reaches it.
data Key
    = Escape
    | Enter
    | Tab
    | Backspace
    deriving stock (Eq, Show, Enum, Bounded)

-- | The modifier keys held down with a key.
data Modifiers = Modifiers
    { modAlt     :: Bool
    , modControl :: Bool
    , modShift   :: Bool
    }
    deriving stock (Eq, Show)

noModifiers :: Modifiers
noModifiers = Modifiers False False False
