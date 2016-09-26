module UTC.Zone
    exposing
        ( Zone
        , name
        , abbreviation
        , offset
        , unpack
        )

import Char
import Combine exposing (Parser)
import Combine.Infix exposing ((<$>), (<*>), (<*), (*>))
import Combine.Num
import String
import UTC.Instant exposing (Instant, Minutes)


{-| Zone represents the opaque type of timezone values.  These are
generally loaded from an external source via the `unpack`
function.

See also http://momentjs.com/timezone/docs/#/data-formats/packed-format/.
-}
type Zone
    = Zone
        { name : String
        , spans : List Span
        }


type alias Span =
    { start : Instant
    , end : Instant
    , abbreviation : String
    , offset : Minutes
    }


{-| Given a Zone, name returns its unique name.
-}
name : Zone -> String
name (Zone { name }) =
    name


{-| Given an arbitrary Instant and a Zone, abbreviation returns Just
the Zone's abbreviation at that Instant or Nothing.
-}
abbreviation : Instant -> Zone -> Maybe String
abbreviation instant (Zone { spans }) =
    find instant spans
        |> Maybe.map .abbreviation


{-| Given an arbitrary Instant and a Zone, offset returns Just the
Zone's UTC offset in minutes at that Instant or Nothing.
-}
offset : Instant -> Zone -> Maybe Int
offset instant (Zone { spans }) =
    find instant spans
        |> Maybe.map .offset


find : Instant -> List Span -> Maybe Span
find instant spans =
    let
        go xs =
            case xs of
                [] ->
                    Nothing

                x :: xs ->
                    if instant >= x.start && instant < x.end then
                        Just x
                    else
                        go xs
    in
        go spans


{-| unpack decodes a packed zone data object into a Zone value.

See also http://momentjs.com/timezone/docs/#/data-formats/packed-format/
-}
unpack : String -> Result (List String) Zone
unpack data =
    case Combine.parse packedZone data of
        ( Err errors, _ ) ->
            Err errors

        ( Ok zone, _ ) ->
            Ok zone


type alias PackedZone =
    { name : String
    , abbrevs : List String
    , offsets : List Int
    , indices : List Int
    , diffs : List Float
    }


{-| packedZone parses a zone data string into a Zone, validating that
the data fromat invariants hold.
-}
packedZone : Parser Zone
packedZone =
    let
        name =
            Combine.regex "[^|]+"
                <* Combine.string "|"

        abbrevs =
            Combine.sepBy1 (Combine.string " ") (Combine.regex "[A-Z]+")
                <* Combine.string "|"

        offsets =
            List.map floor
                <$> Combine.sepBy1 (Combine.string " ") base60
                <* Combine.string "|"

        indices =
            List.map (\n -> floor <| unsafeBase60 1 n "")
                <$> Combine.many1 (Combine.regex "[0-9a-zA-Z]")
                <* Combine.string "|"

        diffs =
            List.map ((*) 60000)
                <$> Combine.sepBy1 (Combine.string " ") base60
                <* Combine.end

        decode =
            PackedZone
                <$> name
                <*> abbrevs
                <*> offsets
                <*> indices
                <*> diffs

        validate data =
            let
                abbrevs =
                    List.length data.abbrevs

                offsets =
                    List.length data.offsets

                maxIndex =
                    List.maximum data.indices
                        |> Maybe.withDefault 0
            in
                if abbrevs /= offsets then
                    Combine.fail [ "abbrevs and offsets have different lengths" ]
                else if maxIndex >= abbrevs then
                    Combine.fail [ "highest index is longer than both abbrevs and offsets" ]
                else if List.isEmpty data.diffs then
                    Combine.fail [ "diffs is empty" ]
                else
                    Combine.succeed data

        span instants data i idx =
            { start = instants !! i
            , end = instants !! (i + 1)
            , abbreviation = data.abbrevs !! idx
            , offset = data.offsets !! idx
            }

        convert data =
            let
                instants =
                    List.scanl (+) (data.diffs !! 0) (List.drop 1 data.diffs)

                -- surround instants with 0 and infinity
                instants' =
                    [ 0 ] ++ instants ++ [ 1 / 0 ]
            in
                Zone
                    { name = data.name
                    , spans = List.indexedMap (span instants' data) data.indices
                    }
    in
        convert <$> (decode `Combine.andThen` validate)


base60 : Parser Float
base60 =
    unsafeBase60
        <$> Combine.Num.sign
        <*> base60String
        <*> Combine.optional "" (Combine.string "." *> base60String)


base60String : Parser String
base60String =
    Combine.regex "[0-9a-zA-Z]+"


unsafeBase60 : Int -> String -> String -> Float
unsafeBase60 sign whole frac =
    let
        toNum c =
            let
                n =
                    Char.toCode c |> toFloat
            in
                if n > 96 then
                    n - 87
                else if n > 64 then
                    n - 29
                else
                    n - 48

        toWhole cs acc =
            case cs of
                [] ->
                    acc

                c :: cs ->
                    toWhole cs (60 * acc + toNum c)

        toFrac cs mul acc =
            let
                mul' =
                    mul / 60
            in
                case cs of
                    [] ->
                        acc

                    c :: cs ->
                        toFrac cs mul' (acc + mul' * toNum c)
    in
        toWhole (String.toList whole) 0
            |> toFrac (String.toList frac) 1
            |> ((*) (toFloat sign))


(!!) : List a -> Int -> a
(!!) xs i =
    case List.head (List.drop i xs) of
        Nothing ->
            Debug.crash ("index too large: xs=" ++ toString xs ++ " i=" ++ toString i)

        Just x ->
            x