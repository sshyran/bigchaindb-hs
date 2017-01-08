{-# LANGUAGE OverloadedStrings #-}

module CryptoConditions.TestFiveBells
  ( fiveBellsSuite
  ) where


import Control.Monad.Trans.Except

import Test.Tasty
import Test.Tasty.HUnit

import Data.ASN1.Encoding 
import Data.ASN1.BinaryEncoding
import Data.Aeson
import Data.Quickson
import Data.Maybe
import Data.Monoid
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Base64 as B64
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)

import System.IO.Unsafe

import BigchainDB.Crypto
import Interledger.CryptoConditions.Standard
import Interledger.CryptoConditions.Encoding


fiveBellsSuite :: TestTree
fiveBellsSuite = testGroup "fiveBellsSuites"
  [ testMinimalEd25519
  , testMinimalPreimage
  , testMinimalThreshold
  , testHashing
  ]


suiteJson :: FromJSON a => FilePath -> a
suiteJson file = unsafePerformIO $ do
  let path = "ext/five-bells-condition/testsuite/valid/" <> file
  fromJust . decodeStrict <$> BS.readFile path


fromB16 :: T.Text -> BS.ByteString    
fromB16 t = let (r,"") = B16.decode $ encodeUtf8 t
             in r

fromB64 :: T.Text -> BS.ByteString    
fromB64 = either error id . b64DecodeStripped . encodeUtf8


fromB64Key :: B58ED2Key k => T.Text -> k
fromB64Key k = either error id $ (runExcept . fromData $ fromB64 k)


qu :: FromJSON a => Value -> BS.ByteString -> a
qu val q = either error id $ quicksonParse q >>= flip quicksonExecute val


compareASN1 :: BS.ByteString -> BS.ByteString -> IO ()
compareASN1 a b = decodeASN1' DER a @?= decodeASN1' DER b


testMinimalEd25519 :: TestTree
testMinimalEd25519 = testGroup f
  [ testCase "binary condition" $ encodeCondition cond @?= condBin
  , testCase "uri" $ getURI cond @?= condUri
  , testCase "fulfillment" $ getFulfillment cond @?= Just ffillment
  , testCase "verify" $ do
      verifyStandard (encodeUtf8 msg) ffillment condUri @?= Passed
  ]
  where
    f = "0004_test-minimal-ed25519.json"
    val = suiteJson f
    (PK pub) = fromB64Key $ qu val "{json:{publicKey}}"
    (Sig sig) = fromB64Key $ qu val "{json:{signature}}"
    condBin = fromB16 $ qu val "{conditionBinary}"
    ffillment = fromB16 $ qu val "{fulfillment}"
    (msg,condUri) = qu val "{message,conditionUri}"
    cond = fulfillEd25519 pub sig $ ed25519Condition pub


testMinimalPreimage :: TestTree
testMinimalPreimage = testGroup f
  [ testCase "binary condition" $ encodeCondition cond @?= condBin
  , testCase "uri" $ getURI cond @?= condUri
  , testCase "fulfillment" $ getFulfillment cond @?= Just ffillment
  , testCase "verify" $
      verifyStandard (encodeUtf8 msg) ffillment condUri @?= Passed
  ]
  where
    f = "0000_test-minimal-preimage.json"
    val = suiteJson f
    preimage = encodeUtf8 $ qu val "{json:{preimage}}"
    condBin = fromB16 $ qu val "{conditionBinary}"
    ffillment = fromB16 $ qu val "{fulfillment}"
    (msg,condUri) = qu val "{message,conditionUri}"
    cond = preimageCondition preimage


testMinimalThreshold :: TestTree
testMinimalThreshold = testGroup f
  [ testCase "binary condition" $ encodeCondition cond `compareASN1` condBin
  , testCase "uri" $ getURI cond @?= condUri
  , testCase "fulfillment" $
      fromJust (getFulfillment cond) `compareASN1` ffillment
  , testCase "verify" $ do
      print $ decodeASN1' DER ffillment
      verifyStandard (encodeUtf8 msg) ffillment condUri @?= Passed
  ]
  where
    f = "0002_test-minimal-threshold.json"
    val = suiteJson f
    t = qu val "{json:{threshold}}"
    [preimage] = encodeUtf8 <$> qu val "{json:{subfulfillments:[{preimage}]}}"
    condBin = fromB16 $ qu val "{conditionBinary}"
    ffillment = fromB16 $ qu val "{fulfillment}"
    (msg,condUri) = qu val "{message,conditionUri}"
    cond = Threshold t [preimageCondition preimage]


testHashing = testCase "testHashing" $ do
  let (Right a) = B64.decode "MDeABTIwMTY6gQMBAACiKaQngCBTViEV1bSU4j5JUXc9sM/i3+VV5+P/60Hk/XXK98FqgYEDAgAA"
  verifyStandard "" a "" @?= Passed
