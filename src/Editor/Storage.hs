module Editor.Storage
  ( Saved (..)
  ) where

import Relude
import Editor.Model (CodeCell)

data Saved = Saved {
    savedCodeCells :: NonEmpty CodeCell
    }
  deriving stock (Eq, Show, Read)
