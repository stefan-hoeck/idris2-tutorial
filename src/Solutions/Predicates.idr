module Solutions.Predicates

%default total

--------------------------------------------------------------------------------
--          Preconditions
--------------------------------------------------------------------------------

data NonEmpty : (as : List a) -> Type where
  IsNonEmpty : NonEmpty (h :: t)

-- 1

tail : (as : List a) -> {auto 0 _ : NonEmpty as} -> List a
tail (_ :: xs) = xs
tail [] impossible

-- 2

concat1 : Semigroup a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
concat1 (h :: t) = foldl (<+>) h t

foldMap1 :  Semigroup m
         => (a -> m)
         -> (as : List a)
         -> {auto 0 _ : NonEmpty as}
         -> m
foldMap1 f (h :: t) = foldl (\x,y => x <+> f y) (f h) t

-- 3

maximum : Ord a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
maximum (x :: xs) = foldl max x xs

minimum : Ord a => (as : List a) -> {auto 0 _ : NonEmpty as} -> a
minimum (x :: xs) = foldl min x xs

-- 4

data Positive : Nat -> Type where
  IsPositive : Positive (S n)

saveDiv : (m,n : Nat) -> {auto 0 _ : Positive n} -> Nat
saveDiv m (S k) = go 0 m k
  where go : (res, rem, sub : Nat) -> Nat
        go res 0       _     = res
        go res (S rem) 0     = go (res + 1) rem k
        go res (S rem) (S x) = go res rem x

-- 5

data IsJust : Maybe a -> Type where
  ItIsJust : IsJust (Just v)

Uninhabited (IsJust Nothing) where
  uninhabited ItIsJust impossible

isJust : (m : Maybe a) -> Dec (IsJust m)
isJust Nothing  = No uninhabited
isJust (Just x) = Yes ItIsJust

-- 6

data IsLeft : Either e a -> Type where
  ItIsLeft : IsLeft (Left v)

Uninhabited (IsLeft $ Right w) where
  uninhabited ItIsLeft impossible

isLeft : (v : Either e a) -> Dec (IsLeft v)
isLeft (Right _) = No uninhabited
isLeft (Left x)  = Yes ItIsLeft

data IsRight : Either e a -> Type where
  ItIsRight : IsRight (Right v)

Uninhabited (IsRight $ Left w) where
  uninhabited ItIsRight impossible

isRight : (v : Either e a) -> Dec (IsRight v)
isRight (Left _)  = No uninhabited
isRight (Right x) = Yes ItIsRight
