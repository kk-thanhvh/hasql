module Hasql.Core.Pipeline where

import Hasql.Prelude
import Hasql.Core.Model
import qualified ByteString.StrictBuilder as B
import qualified BinaryParser as D
import qualified Hasql.Core.ParseMessageStream as A
import qualified Hasql.Protocol.Encoding as K


{-|
A builder of concatenated outgoing messages and
a parser of the stream of incoming messages.
-}
data Pipeline result =
  Pipeline !B.Builder !(ExceptT Text A.ParseMessageStream result)

instance Functor Pipeline where
  {-# INLINE fmap #-}
  fmap mapping (Pipeline builder parse) =
    Pipeline builder (fmap mapping parse)

instance Applicative Pipeline where
  {-# INLINE pure #-}
  pure =
    Pipeline mempty . return
  {-# INLINE (<*>) #-}
  (<*>) (Pipeline leftBuilder leftParse) (Pipeline rightBuilder rightParse) =
    Pipeline (leftBuilder <> rightBuilder) (leftParse <*> rightParse)

{-# INLINE parse #-}
parse :: ByteString -> ByteString -> Vector Word32 -> Pipeline ()
parse preparedStatementName query oids =
  Pipeline builder parse
  where
    builder = K.parseMessage preparedStatementName query oids
    parse = lift A.parseComplete

{-# INLINE bind #-}
bind :: ByteString -> ByteString -> Vector (Maybe B.Builder) -> Pipeline ()
bind portalName preparedStatementName parameters =
  Pipeline builder parse
  where
    builder = K.binaryFormatBindMessage portalName preparedStatementName parameters
    parse = lift A.bindComplete

{-# INLINE execute #-}
execute :: ByteString -> A.ParseMessageStream (Either Text result) -> Pipeline result
execute portalName parse =
  Pipeline builder (ExceptT parse)
  where
    builder = K.unlimitedExecuteMessage portalName

{-# INLINE sync #-}
sync :: Pipeline ()
sync =
  Pipeline K.syncMessage (lift A.readyForQuery)
