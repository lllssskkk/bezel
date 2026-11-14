{-# LANGUAGE Arrows #-}
{-# LANGUAGE LambdaCase #-}


module Editor.App(Action(..), Output(..), editor) where

import Relude
import qualified Data.Text as T
import FRP.Yampa
import Editor.Model
import Editor.Storage
import Editor.View

data Action
  = Insert (Maybe CodeCellId) T.Text
  | Destroy CodeCellId
  deriving stock (Eq, Show)


data Output = Output
                {
                  outView   :: View
                , outSaved  :: Saved           -- ^ what should survive a restart
                , outAdded  :: Event CodeCell      -- ^ a code cell was created
                , outNextId :: CodeCellId      -- ^ the id the next new code cell will get
                }
    deriving stock (Eq, Show)


editor :: Saved -> SF (Event Action) Output
editor saved = proc action -> do
    rec
        -- -- The state just before this sample. An action is judged against the
        -- -- state it was taken in, and going through 'iPre' is also what keeps the
        -- -- recursion between these definitions well founded.
        -- prevCodeCells <- iPre (savedCodeCells saved) -< cells

        -- A new code cell takes the next free id. The delayed accumulator still shows
        -- the id from before this sample, which is the one the new code cell gets.
        nextId <- dAccumHoldBy (\i _ -> succCodeCellId i) (nextCodeCellId (savedCodeCells saved)) -< created
        let placed  = (\(anchor, content) -> (anchor, CodeCell nextId content )) <$> mapFilterE inserted action
            created = snd <$> placed

        -- "Mark all" completes everything, unless everything already is complete,
        -- in which case it reopens everything.
        let edits = foldr (\start acc -> mergeBy (.) start acc) NoEvent
                                [ (uncurry insertAfter) <$> placed
                                , removeCodeCell <$> mapFilterE destroyed action
                                ]

        cells <- accumHoldBy (flip ($)) (savedCodeCells saved) -< edits


    returnA -< Output
                    {
                       outView   = mkView  cells
                    ,  outSaved  = Saved  cells
                    , outAdded  = created
                    , outNextId = if isEvent created then succCodeCellId nextId else nextId
                    }


-- | Where a new todo goes and its title, unless the title is blank.
inserted :: Action -> Maybe (Maybe CodeCellId, T.Text)
inserted = \case
    Insert anchor raw -> (,) anchor <$> normaliseTitle raw
    _                 -> Nothing

-- | A title with the surrounding blanks dropped, or 'Nothing' when no text
-- would be left: blank titles are never stored.
normaliseTitle :: T.Text -> Maybe T.Text
normaliseTitle raw
    | T.null title = Nothing
    | otherwise    = Just title
    where
    title = T.strip raw


destroyed :: Action -> Maybe CodeCellId
destroyed = \case
  Destroy i -> Just i
  _         -> Nothing
