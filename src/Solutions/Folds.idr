module Solutions.Folds

import Data.Maybe
import Data.SnocList

%default total

--------------------------------------------------------------------------------
--          Recursion
--------------------------------------------------------------------------------

-- 1

anyList : (a -> Bool) -> List a -> Bool
anyList p []        = False
anyList p (x :: xs) = case p x of
  False => anyList p xs
  True  => True

allList : (a -> Bool) -> List a -> Bool
allList p []        = True
allList p (x :: xs) = case p x of
  True  => allList p xs
  False => False

-- 2

findList : (a -> Bool) -> List a -> Maybe a
findList f []        = Nothing
findList f (x :: xs) = if f x then Just x else findList f xs

-- 3

collectList : (a -> Maybe b) -> List a -> Maybe b
collectList f []        = Nothing
collectList f (x :: xs) = case f x of
  Just vb => Just vb
  Nothing => collectList f xs

-- Note utility function `Data.Maybe.toMaybe` in the implementation
lookupList : Eq a => a -> List (a,b) -> Maybe b
lookupList va = collectList (\(k,v) => toMaybe (k == va) v)

-- 4

mapTR : (a -> b) -> List a -> List b
mapTR f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx :< f x) xs

-- 5

filterTR : (a -> Bool) -> List a -> List a
filterTR f = go Lin
  where go : SnocList a -> List a -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = if f x then go (sx :< x) xs else go sx xs

-- 6

mapMaybeTR : (a -> Maybe b) -> List a -> List b
mapMaybeTR f = go Lin
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = case f x of
          Just vb => go (sx :< vb) xs
          Nothing => go sx xs

catMaybesTR : List (Maybe a) -> List a
catMaybesTR = mapMaybeTR id

-- 7

concatTR : List a -> List a -> List a
concatTR xs ys = (Lin <>< xs) <>> ys

-- 8

bindTR : List a -> (a -> List b) -> List b
bindTR xs f = go Lin xs
  where go : SnocList b -> List a -> List b
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx <>< f x) xs

joinTR : List (List a) -> List a
joinTR = go Lin
  where go : SnocList a -> List (List a) -> List a
        go sx []        = sx <>> Nil
        go sx (x :: xs) = go (sx <>< x) xs

--------------------------------------------------------------------------------
--          Tests
--------------------------------------------------------------------------------

lengthTR : List a -> Nat
lengthTR = foldl (const . S) 0

iterateTR : Nat -> (a -> a) -> a -> List a
iterateTR k f = go k Lin
  where go : Nat -> SnocList a -> a -> List a
        go 0     sx _ = sx <>> Nil
        go (S k) sx x = go k (sx :< x) (f x)


values : List Integer
values = iterateTR 100000 (+1) 0

main : IO ()
main = do
  printLn . lengthTR $ mapTR (*2)  values
  printLn . lengthTR $ filterTR (\n => n `mod` 2 == 0)  values
  printLn . lengthTR $ mapMaybeTR (\n => toMaybe (n `mod` 2 == 1) "foo")  values
  printLn . lengthTR $ concatTR values values
  printLn . lengthTR $ bindTR [1..500] (\n => iterateTR n (+1) n)
