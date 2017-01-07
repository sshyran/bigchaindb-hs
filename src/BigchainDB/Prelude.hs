module BigchainDB.Prelude
  ( module CA
  , module CM
  , module DM
  , module TC
  , module TE
  , exceptToFail
  ) where


import Control.Monad as CM (join, when)
import Control.Applicative as CA
import Control.Monad.Trans.Except as TE
import Control.Monad.Trans.Class as TC

import Data.Functor.Identity
import Data.Monoid as DM


exceptToFail :: Monad m => Except String a -> m a
exceptToFail = either fail return . runIdentity . runExceptT