module Editor.View(View(..),mkView) where

import Relude
import Editor.Model

data View = View
  { viewCodeCells       :: NonEmpty CodeCell  -- ^ the todos the filter lets through, in list order
  , viewPlaceholder :: CodeCell    -- ^ shown in place of an empty list
  }
  deriving stock (Eq, Show)



mkView ::  NonEmpty CodeCell -> View
mkView  ccs = View
            { viewCodeCells       = ccs
            , viewPlaceholder = CodeCell (CodeCellId 0) "Modify this cell"
            }
