module Solutions.Dependent

%default total

--------------------------------------------------------------------------------
--          Length-Indexed Lists
--------------------------------------------------------------------------------

data Vect : (len : Nat) -> Type -> Type where
  Nil  : Vect 0 a
  (::) : a -> Vect n a -> Vect (S n) a

-- 1
head : Vect (S n) a -> a
head (x :: _) = x
head Nil impossible

-- 2
tail : Vect (S n) a -> Vect n a
tail (_ :: xs) = xs
tail Nil impossible

-- 3
zipWith3 : (a -> b -> c -> d) -> Vect n a -> Vect n b -> Vect n c -> Vect n d
zipWith3 f []        []        []        = []
zipWith3 f (x :: xs) (y :: ys) (z :: zs) = f x y z :: zipWith3 f xs ys zs

-- 4
-- Since we only have a `Semigroup` constraint, we can't conjure
-- a value of type `a` out of nothing in case of an empty list.
-- We therefore have to return a `Nothing` in case of an empty list.
foldSemi : Semigroup a => List a -> Maybe a
foldSemi []        = Nothing
foldSemi (x :: xs) = Just . maybe x (x <+>) $ foldSemi xs

-- 5
-- the `Nil` case is impossible here, so unlike in Exercise 4,
-- we don't need to wrap the result in a `Maybe`.
-- However, we need to pattern match on the tail of the Vect to
-- decide whether to invoke `foldSemiVect` recursively ore not
foldSemiVect : Semigroup a => Vect (S n) a -> a
foldSemiVect (x :: [])         = x
foldSemiVect (x :: t@(_ :: _)) = x <+> foldSemiVect t

-- 6
iterate : (n : Nat) -> (a -> a) -> a -> Vect n a
iterate 0     _ _ = Nil
iterate (S k) f v = v :: iterate k f (f v)

-- 7
generate : (n : Nat) -> (s -> (s,a)) -> s -> Vect n a
generate 0     _ _ = Nil
generate (S k) f v =
  let (v', va) = f v
   in va :: generate k f v'

-- 8
fromList : (as : List a) -> Vect (length as) a
fromList []        = []
fromList (x :: xs) = x :: fromList xs

-- 9
-- Lookup the type and implementation of functions `maybe` `const` and
-- try figuring out, what's going on here. An alternative implementation
-- would of course just pattern match on the argument.
maybeSize : Maybe a -> Nat
maybeSize = maybe 0 (const 1)

fromMaybe : (m : Maybe a) -> Vect (maybeSize m) a
fromMaybe Nothing  = []
fromMaybe (Just x) = [x]
