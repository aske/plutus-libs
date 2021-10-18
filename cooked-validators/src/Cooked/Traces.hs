{-# LANGUAGE GADTs #-}
module Cooked.Traces where

import Control.Arrow (first)

import Cooked.MockChain
import Cooked.Tx.Constraints
import Cooked.Generator

type TxSkelGen m a b = a -> MockChainT m (TxSkel, b)

modifyTxSkelGen :: (Monad m)
                => (TxSkel -> TxSkel)
                -> TxSkelGen m a b -> TxSkelGen m a b
modifyTxSkelGen f g = fmap (first f) . g

data Tr m a b where
  Empty   :: Tr m a a
  Step    :: TxSkelGen m a b -> Tr m b c -> Tr m a c
  Stutter :: Tr m a b -> Tr m a b

modifyTr :: (Monad m) => (TxSkel -> TxSkel) -> Tr m a b -> Tr m a b
modifyTr _ Empty        = Empty
modifyTr f (Step g tr)  = Step (modifyTxSkelGen f g) (modifyTr f tr)
modifyTr f (Stutter tr) = Stutter (modifyTr f tr)

executeTr :: (Monad m) => Tr m a b -> a -> MockChainT m b
executeTr Empty        a = return a
executeTr (Stutter tr) a = executeTr tr a
executeTr (Step g tr)  a = do
  (txSkel, b) <- g a
  validateTxFromSkeleton txSkel
  executeTr tr b