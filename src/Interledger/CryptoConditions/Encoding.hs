{-# LANGUAGE OverloadedStrings #-}

module Interledger.CryptoConditions.Encoding where


import Crypto.Error (CryptoFailable(..))
import qualified Crypto.PubKey.Ed25519 as Ed2

import Data.ASN1.BinaryEncoding
import Data.ASN1.BinaryEncoding.Raw
import Data.ASN1.Encoding
import Data.ASN1.Parse
import Data.ASN1.Types
import Data.Bits
import qualified Data.ByteArray as BA
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.ByteString.Base64.URL as B64
import qualified Data.ByteString.Char8 as C8
import Data.List (sortOn)
import Data.Monoid
import Data.Word


b64EncodeStripped :: BS.ByteString -> BS.ByteString
b64EncodeStripped bs =
  let b64 = B64.encode bs
   in case C8.elemIndex '=' b64 of Just i -> BS.take i b64
                                   Nothing -> b64


b64DecodeStripped :: BS.ByteString -> Either String BS.ByteString
b64DecodeStripped bs = 
  let r = 4 - mod (BS.length bs) 4
      n = if r == 4 then 0 else r
   in B64.decode $ bs <> C8.replicate n '='


x690Sort :: [BS.ByteString] -> [BS.ByteString]
x690Sort = sortOn (\bs -> (BS.length bs, bs))


x690SortAsn :: [[ASN1]] -> [[ASN1]]
x690SortAsn = sortOn (\a -> let b = encodeASN1' DER a in (BS.length b, b))


asnChoice2 :: Int -> [ASN1] -> [ASN1]
asnChoice2 tid body = let c = Container Context tid
                       in Start c : body ++ [End c]


asnSequence :: [ASN1] -> [ASN1]
asnSequence args = [Start Sequence] ++ args ++ [End Sequence]


asnSeq :: ASN1ConstructionType -> [ASN1] -> [ASN1]
asnSeq c args = [Start c] ++ args ++ [End c]


asnSequenceBS :: [BS.ByteString] -> BS.ByteString
asnSequenceBS args =
  let len = foldl (+) 0 $ BS.length <$> args
      lenPacked = BS.pack $ putLength $ mkSmallestLength len
   in "0" <> lenPacked <> BS.concat args


fiveBellsThingy :: Integral i => i -> [BS.ByteString] -> [ASN1]
fiveBellsThingy tid bs =
  let c = Container Context $ fromIntegral tid
   in Start c : [Other Context i s | (i,s) <- zip [0..] bs] ++ [End c]


mkSmallestLength :: Int -> ASN1Length
mkSmallestLength i
  | i < 0x80  = LenShort i
  | otherwise = LenLong (nbBytes i) i
  where nbBytes nb = if nb > 255 then 1 + nbBytes (nb `div` 256) else 1


putLength :: ASN1Length -> [Word8]
putLength (LenShort i)
    | i < 0 || i > 0x7f = error "putLength: short length is not between 0x0 and 0x80"
    | otherwise         = [fromIntegral i]
putLength (LenLong _ i)
    | i < 0     = error "putLength: long length is negative"
    | otherwise = lenbytes : lw
        where
            lw       = bytesOfUInt $ fromIntegral i
            lenbytes = fromIntegral (length lw .|. 0x80)
putLength (LenIndefinite) = [0x80]


bytesOfUInt :: Integer -> [Word8]
bytesOfUInt = reverse . list
  where list i = if i <= 0xff
                    then [fromIntegral i]
                    else (fromIntegral i .&. 0xff) : list (i `shiftR` 8)


parseASN1 :: BS.ByteString -> ParseASN1 a -> Either String a
parseASN1 bs act = showErr decoded >>= runParseASN1 act
  where decoded = decodeASN1 DER $ BL.fromStrict bs
        showErr = either (Left . show) Right


toKey :: CryptoFailable a -> Either String a
toKey r = case r of
   CryptoPassed a -> return a
   CryptoFailed e -> Left $ show e


toData :: BA.ByteArrayAccess a => a -> BS.ByteString
toData = BS.pack . BA.unpack
