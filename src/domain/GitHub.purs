module Domain.GitHub where

type Profile =
  { followers :: Int
  }

type Contributions =
  { total ::
      { lastYear :: Int
      }
  , contributions :: Array
      { level :: Int
      }
  }

type Activity =
  { contributions :: Int
  , followers :: Int
  , levels :: Array Int
  }
