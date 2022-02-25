module Solutions.Prim

import Data.List

%default total

--------------------------------------------------------------------------------
--          Working with Strings
--------------------------------------------------------------------------------

-- 1

map : (Char -> Char) -> String -> String
map f = pack . map f . unpack

filter : (Char -> Bool) -> String -> String
filter f = pack . filter f . unpack

mapMaybe : (Char -> Maybe Char) -> String -> String
mapMaybe f = pack . mapMaybe f . unpack

-- 2

foldl : (a -> Char -> a) -> a -> String -> a
foldl f v = foldl f v . unpack

foldMap : Monoid m => (Char -> m) -> String -> m
foldMap f = foldMap f . unpack

-- 3

traverse : Applicative f => (Char -> f Char) -> String -> f String
traverse fun = map pack . traverse fun . unpack

-- 4
(>>=) : String -> (Char -> String) -> String
str >>= f = foldMap f $ unpack str
