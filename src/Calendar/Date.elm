module Calendar.Date
    exposing
        ( Date
        , DateDelta
        , date
        , year
        , month
        , day
        , setYear
        , setMonth
        , setDay
        , addYears
        , addMonths
        , addDays
        , delta
        , toTuple
        , fromTuple
        , isValidDate
        , isLeapYear
        , daysInMonth
        )

{-| This module defines a timezone-independent Date type which can
represent any date of the Gregorian calendar.

# Dates
@docs Date, date, year, month, day

# Manipulating Dates
@docs setYear, setMonth, setDay, addYears, addMonths, addDays

# Subtracting Dates
@docs DateDelta, delta

# Helper functions
@docs toTuple, fromTuple, isValidDate, isLeapYear, daysInMonth
-}


{-| Date is the opaque type for all Date values.  Values of this type
are guaranteed to represent valid Gregorian calendar dates.
-}
type Date
    = Date
        { year : Int
        , month : Int
        , day : Int
        }


{-| DateDelta represents a delta between two dates.
-}
type alias DateDelta =
    { years : Int
    , months : Int
    , days : Int
    }


{-| date constructs a Date value given a year, a month and a day.  If
the constructed value is invalid, Nothing is returned.
-}
date : Int -> Int -> Int -> Maybe Date
date year month day =
    if isValidDate year month day then
        Just <| Date { year = year, month = month, day = day }
    else
        Nothing


{-| year returns a Date's year as an Int.
-}
year : Date -> Int
year (Date { year }) =
    year


{-| month returns a Date's month as an Int. Guaranteed to be in the
range [1, 12].
-}
month : Date -> Int
month (Date { month }) =
    month


{-| day returns a Date's year as an Int. Guaranteed to be valid for
the Date's (year, month) pair and in the range [1, 31].
-}
day : Date -> Int
day (Date { day }) =
    day


{-| setYear updates a Date's year, returning Nothing if the updated
date is invalid or Just the new Date.
-}
setYear : Int -> Date -> Maybe Date
setYear year (Date ({ month, day } as date)) =
    if isValidDate year month day then
        Just <| Date { date | year = year }
    else
        Nothing


{-| setMonth updates a Date's month, returning Nothing if the updated
date is invalid or Just the new Date.
-}
setMonth : Int -> Date -> Maybe Date
setMonth month (Date ({ year, day } as date)) =
    if isValidDate year month day then
        Just <| Date { date | month = month }
    else
        Nothing


{-| setDay updates a Date's day, returning Nothing if the updated
date is invalid or Just the new Date.
-}
setDay : Int -> Date -> Maybe Date
setDay day (Date ({ year, month } as date)) =
    if isValidDate year month day then
        Just <| Date { date | day = day }
    else
        Nothing


{-| addYears adds a relative number (positive or negative) of years to
a Date, ensuring that the return value represents a valid Date.  If
the new date is not valid, days are subtracted from it until a valid
Date can be produced.
-}
addYears : Int -> Date -> Date
addYears years (Date ({ year, month, day } as date)) =
    firstValid (year + years) month day


{-| addMonths adds a relative number (positive or negative) of months to
a Date, ensuring that the return value represents a valid Date.  Its
semantics are the same as `addYears`.
-}
addMonths : Int -> Date -> Date
addMonths months (Date ({ year, month, day } as date)) =
    let
        sign =
            if year < 0 then
                -1
            else
                1

        ms =
            abs year * 12 + month - 1 + months
    in
        firstValid (sign * ms // 12) ((ms `rem` 12) + 1) day


{-| days adds an exact number (positive or negative) of days to a
Date.  Adding or subtracting days always produces a valid Date so
there is no fuzzing logic here like there is in `add{Months,Years}`.
-}
addDays : Int -> Date -> Date
addDays days (Date ({ year, month, day } as date)) =
    daysFromYearMonthDay year month day
        |> ((+) days)
        |> dateFromDays


{-| delta returns the relative number of years, months and days between two Dates.
-}
delta : Date -> Date -> DateDelta
delta (Date d1) (Date d2) =
    { years = d1.year - d2.year
    , months = (abs d1.year * 12 + d1.month) - (abs d2.year * 12 + d2.month)
    , days =
        daysFromYearMonthDay d1.year d1.month d1.day
            - daysFromYearMonthDay d2.year d2.month d2.day
    }


{-| toTuple converts a Date value into a (year, month, day) tuple.
This is useful if you want to use Dates as Dict keys.
-}
toTuple : Date -> ( Int, Int, Int )
toTuple (Date { year, month, day }) =
    ( year, month, day )


{-| fromTuple converts a (year, month, day) tuple into a Date value.
-}
fromTuple : ( Int, Int, Int ) -> Maybe Date
fromTuple ( year, month, day ) =
    date year month day


{-| isValidDate returns True if the given year, month and day
represent a valid date.
-}
isValidDate : Int -> Int -> Int -> Bool
isValidDate year month day =
    daysInMonth year month
        |> Maybe.map (\days -> day >= 1 && day <= days)
        |> Maybe.withDefault False


{-| isLeapYear returns True if the given year is a leap year.  The
rules for leap years are as follows:

* A year that is a multiple of 400 is a leap year.
* A year that is a multiple of 100 but not of 400 is not a leap year.
* A year that is a multiple of 4 but not of 100 is a leap year.
-}
isLeapYear : Int -> Bool
isLeapYear y =
    y `rem` 100 == 0 && y `rem` 400 == 0 || y `rem` 4 == 0


{-| daysInMonth returns the number of days in a month given a specific
year, taking leap years into account.

* A regular year has 365 days and the corresponding February has 28 days.
* A leap year has 366 days and the corresponding February has 29 days.
-}
daysInMonth : Int -> Int -> Maybe Int
daysInMonth y m =
    if m >= 1 && m <= 12 then
        Just <| unsafeDaysInMonth y m
    else
        Nothing


unsafeDaysInMonth : Int -> Int -> Int
unsafeDaysInMonth y m =
    if m == 1 then
        31
    else if m == 2 && isLeapYear y then
        29
    else if m == 2 then
        28
    else if m == 3 then
        31
    else if m == 4 then
        30
    else if m == 5 then
        31
    else if m == 6 then
        30
    else if m == 7 then
        31
    else if m == 8 then
        31
    else if m == 9 then
        30
    else if m == 10 then
        31
    else if m == 11 then
        30
    else if m == 12 then
        31
    else
        Debug.crash <| "invalid call to unsafeDaysInMonth: year=" ++ toString y ++ " month=" ++ toString m


firstValid : Int -> Int -> Int -> Date
firstValid year month day =
    let
        ( y, m, d ) =
            if isValidDate year month day then
                ( year, month, day )
            else if isValidDate year month (day - 1) then
                ( year, month, day - 1 )
            else if isValidDate year month (day - 2) then
                ( year, month, day - 2 )
            else
                ( year, month, day - 3 )
    in
        Date { year = y, month = m, day = d }


daysFromYearMonthDay : Int -> Int -> Int -> Int
daysFromYearMonthDay year month day =
    let
        yds =
            daysFromYear year

        mds =
            daysFromYearMonth year month

        dds =
            day - 1
    in
        yds + mds + dds


daysFromYearMonth : Int -> Int -> Int
daysFromYearMonth year month =
    let
        go year month acc =
            if month == 0 then
                acc
            else
                go year (month - 1) (acc + unsafeDaysInMonth year month)
    in
        go year (month - 1) 0


daysFromYear : Int -> Int
daysFromYear y =
    if y > 0 then
        366
            + ((y - 1) * 365)
            + ((y - 1) // 4)
            - ((y - 1) // 100)
            + ((y - 1) // 400)
    else if y < 0 then
        (y * 365)
            + (y // 4)
            - (y // 100)
            + (y // 400)
    else
        0


yearFromDays : Int -> Int
yearFromDays ds =
    let
        y =
            ds // 365

        d =
            daysFromYear y
    in
        if ds <= d then
            y - 1
        else
            y


dateFromDays : Int -> Date
dateFromDays ds =
    let
        d400 =
            daysFromYear 400

        y400 =
            ds // d400

        d =
            ds `rem` d400

        year =
            yearFromDays (d + 1)

        leap =
            if isLeapYear year then
                ((+) 1)
            else
                identity

        doy =
            d - daysFromYear year

        ( month, day ) =
            if doy < 31 then
                ( 1, doy + 1 )
            else if doy < leap 59 then
                ( 2, doy - 31 + 1 )
            else if doy < leap 90 then
                ( 3, doy - leap 59 + 1 )
            else if doy < leap 120 then
                ( 4, doy - leap 90 + 1 )
            else if doy < leap 151 then
                ( 5, doy - leap 120 + 1 )
            else if doy < leap 181 then
                ( 6, doy - leap 151 + 1 )
            else if doy < leap 212 then
                ( 7, doy - leap 181 + 1 )
            else if doy < leap 243 then
                ( 8, doy - leap 212 + 1 )
            else if doy < leap 273 then
                ( 9, doy - leap 243 + 1 )
            else if doy < leap 304 then
                ( 10, doy - leap 273 + 1 )
            else if doy < leap 334 then
                ( 11, doy - leap 304 + 1 )
            else
                ( 12, doy - leap 334 + 1 )
    in
        Date
            { year = year + y400 * 400
            , month = month
            , day = day
            }