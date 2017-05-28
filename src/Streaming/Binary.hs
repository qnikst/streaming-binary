-- | This module implements a method to ingest a sequence of "Data.Binary"
-- encoded records using bounded memory. Minimal example:
--
-- > {-# LANGUAGE TypeApplications #-}
-- >
-- > import Data.Function ((&))
-- > import qualified Data.ByteString.Streaming as Q
-- > import Streaming
-- > import Streaming.Binary
-- > import qualified Streaming.Prelude as S
-- >
-- > -- Interpret all bytes on stdin as a sequence of integers.
-- > -- Print them on-the-fly on stdout.
-- > main = Q.getContents & decoded @Int & S.print

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Streaming.Binary (decoded) where

import qualified Data.Binary.Get as Binary
import Data.Binary (Binary, get)
import qualified Data.ByteString.Streaming as Q
import Data.ByteString.Streaming (ByteString)
import Data.Int (Int64)
import Streaming
import qualified Streaming.Prelude as S

_decode
  :: (Binary a, Monad m)
  => ByteString m r
  -> m (ByteString m r, Int64, Either String a)
_decode = undefined -- TODO implement this.

decoded
  :: (Binary a, Monad m)
  => ByteString m r
  -> Stream (Of a) m (ByteString m r, Int64, Either String r)
decoded = go 0 decoder0
  where
    decoder0 = Binary.runGetIncremental get
    go !total (Binary.Fail leftover nconsumed err) p = do
        return (Q.chunk leftover >> p, total + nconsumed, Left err)
    go !total (Binary.Done "" nconsumed x) p = do
        S.yield x
        lift (Q.nextChunk p) >>= \case
          Left res -> return (return res, total + nconsumed, Right res)
          Right (bs, p') -> do
            go (total + nconsumed) decoder0 (Q.chunk bs >> p')
    go !total (Binary.Done leftover nconsumed x) p = do
        S.yield x
        go (total + nconsumed) decoder0 (Q.chunk leftover >> p)
    go !total (Binary.Partial k) p = do
      lift (Q.nextChunk p) >>= \case
        Left res -> go total (k Nothing) (return res)
        Right (bs, p') -> go total (k (Just bs)) p'