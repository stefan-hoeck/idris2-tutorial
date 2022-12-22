module Data.List.Magic

import Data.List

%default total

-- Here we access private function `revOnto` from
-- module `Data.List`!
lookMumWhatICanDo : (xs,ys : List a) -> reverseOnto xs ys = reverse ys ++ xs
lookMumWhatICanDo xs ys = revOnto xs ys
