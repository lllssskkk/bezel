module Editor.Model(
        CodeCellId(..),
        CodeCell(..),
        nextCodeCellId,
        succCodeCellId,
        insertAfter,
        removeCodeCell,
        defaultCodeCell
        ) where

import Relude
import qualified Data.List.NonEmpty as NE
import Relude.Extra.Foldable1 (maximum1)

newtype CodeCellId = CodeCellId Int
  deriving stock (Eq, Ord, Show, Read)

data CodeCell = CodeCell
  { codeCellId    :: !CodeCellId
  , codeCellContent :: !Text
  }
  deriving stock (Eq, Show, Read)


defaultCodeCell :: CodeCell
defaultCodeCell = CodeCell (CodeCellId 0) "Enter here"

-- | An id that no code cell in the list uses yet.
nextCodeCellId :: NonEmpty CodeCell -> CodeCellId
nextCodeCellId ccs = CodeCellId (1 + maximum1 (0 NE.<| (fmap (\(CodeCell (CodeCellId n) _) -> n) ccs)))

succCodeCellId :: CodeCellId -> CodeCellId
succCodeCellId (CodeCellId n) = CodeCellId (n + 1)


-- | Put a code cell right after another one, or at the end when there is no other
-- one or it is not in the list.
insertAfter :: Maybe CodeCellId -> CodeCell -> NonEmpty CodeCell -> NonEmpty CodeCell
insertAfter anchor cc ccs = case NE.break ((== anchor) . Just . codeCellId) ccs of
  (before, other : after) -> before `NE.prependList` (other NE.<| cc :| after)
  (_, [])                 -> ccs `NE.appendList` [cc]


removeCodeCell :: CodeCellId -> NonEmpty CodeCell -> NonEmpty CodeCell
removeCodeCell i xs = case NE.filter ((/= i) . codeCellId) xs of
                            -- Ensure that NonEmpty CodeCell always has an element
                            [] -> NE.singleton defaultCodeCell
                            other ->   NE.fromList other
