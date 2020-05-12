module Parser (runParser) where

import qualified Data.Array
import qualified Data.List
import qualified Data.Maybe
import Codec.Xlsx
import qualified Data.ByteString.Lazy as L
import Control.Lens
import           Data.Text                        as T hiding (concat, filter,
                                                        length, map, null, zip,
                                                        zipWith, take)

data Lecture = Lecture {name :: String, teacher :: String, room :: String, lecTime :: LectureTime} deriving (Show)
data LectureTime = LectureTime {startTime::String, endTime::String} deriving (Show)

columnStart = 5
columnEnd = 35

rowStart = 2
rowEnd = 815

-- 35, 816

-- time !! ((y + 1) `mod` 7)

timeArray :: [(String, String)]
timeArray = [
  ("09:00:00", "10:30:00"),
  ("10:35:00", "12:05:00"),
  ("12:10:00", "13:40:00"),
  ("14:10:00", "15:40:00"),
  ("15:45:00", "17:15:00"),
  ("17:20:00", "18:50:00"),
  ("18:55:00", "20:25:00"),
  ("20:30:00", "22:00:00")]

getI :: [Text] -> Int -> Text
getI splitted i
  | (i < length splitted) = splitted !! i
  | otherwise = T.pack $ ""

getIWithA :: [(Int, String)] -> Int -> (Int, String)
getIWithA splitted i
  | (i < length splitted) = splitted !! i
  | otherwise = (1, "")

getDay :: Int -> Int
getDay y = ((y - 2) `div` 8)

getTime y = timePair
  where
    timePair = timeArray !! ((y - 1) `mod` 8)

--getContent :: Int -> Int -> IO(Maybe CellText)
getContent x y xlsx = do
  let value = xlsx ^? ixSheet (T.pack $ "Main") . ixCell (x,y) . cellValue . _Just
  return value

foo :: [Int] -> Int -> [(Int, String)] -> Xlsx -> IO([(Int, Lecture)])
foo (y:ys) x date xlsx = do
  word <- getContent y x xlsx
  words <- foo ys x date xlsx

  let objStr = case word of
       Just (CellText a) -> do
        let splitted = (splitOn (T.pack $ "\r\n") a)
        let day = snd (getIWithA date (getDay y))
        let lecTime = LectureTime {startTime = day ++ ":" ++ (fst (getTime y)), endTime = day ++ ":" ++ (snd (getTime y))}
        Lecture {name = T.unpack $ (getI splitted 0), teacher = T.unpack $ (getI splitted 1), room = T.unpack $ (getI splitted 2), lecTime = lecTime}
       Just _ -> Lecture {}
       Nothing -> Lecture {}

  if (Data.Maybe.isJust word) then
    return ((y, objStr) : words)
  else
    return words
foo [] _ _ _ = do return []

goColumns :: [Int] -> [(Int, String)] -> Xlsx -> IO([(Int, [(Int, Lecture)])])
goColumns (column:columns) date xlsx = do
  word <- foo (Data.Array.range (rowStart, rowEnd)) column date xlsx
  words <- goColumns columns date xlsx

  return ((column, word) : words)
goColumns [] _ _ = do return []

format0 str
  | (length str == 2) = str
  | otherwise = "0" ++ str

getDate :: [Int] -> Xlsx -> IO([(Int, String)])
getDate (y:ys) xlsx = do
  word <- getContent y 1 xlsx
  words <- getDate ys xlsx

  let objStr = case word of
         Just (CellText a) -> T.unpack $ a
         Just _ -> ""
         Nothing -> ""

  let splittedDay = splitOn (T.pack $ "/") (T.pack $ objStr)

  let parsedDay = (T.unpack $ splittedDay !! 2) ++ "-" ++ (format0 (T.unpack $ splittedDay !! 1)) ++ "-" ++ (format0 (T.unpack $ splittedDay !! 0))

  if (Data.Maybe.isJust word) then
    return ((getDay y, parsedDay) : words)
  else
    return words
getDate [] _ = do return []

runParser :: IO ()
runParser = do
  file <- L.readFile "electives.xlsx"
  let xlsx = toXlsx file
  date <- getDate (Data.Array.range (rowStart, rowEnd)) xlsx
  print date
  dates <- goColumns (Data.Array.range (columnStart, columnEnd)) date xlsx
  print dates