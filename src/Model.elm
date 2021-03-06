module Model exposing (..)

import Helper exposing (..)
import Json.Decode
import Json.Encode
import List.Extra exposing (find)
import Maybe exposing (withDefault)
import Time


type alias Model =
    { entries : List Entry
    , field : String
    , uid : Int
    , visibility : Maybe String
    , now : Time.Posix
    , edit : Edit
    }


type alias Entry =
    { description : String
    , completed : Bool
    , editing : Bool
    , id : Int
    , doneAt : List Time.Posix
    , tags : List String
    }


type Edit
    = NoEdit
    | EditDate Int Int String
    | EditTag Int String


emptyModel : Model
emptyModel =
    { entries = []
    , visibility = Nothing
    , field = ""
    , uid = 0
    , now = Time.millisToPosix 0
    , edit = NoEdit
    }


newEntry : String -> Int -> Maybe String -> Entry
newEntry desc id tag =
    { description = desc
    , completed = False
    , editing = False
    , id = id
    , doneAt = []
    , tags =
        case tag of
            Just t ->
                [ t ]

            Nothing ->
                []
    }


due : Entry -> Maybe Time.Posix
due e =
    case List.head e.doneAt of
        Nothing ->
            Nothing

        Just lastCheck ->
            case avgDiff (List.map Time.posixToMillis e.doneAt) of
                Nothing ->
                    Nothing

                Just avg_diff ->
                    Just ((Time.posixToMillis lastCheck + avg_diff) |> Time.millisToPosix)


sortEntries : List Entry -> Time.Posix -> List Entry
sortEntries l now =
    let
        cmp_val a =
            ( due a |> withDefault now |> Time.posixToMillis
            , case a.doneAt of
                [] ->
                    0

                done :: _ ->
                    Time.posixToMillis done
            )
    in
    List.sortWith (\a b -> compare (cmp_val a) (cmp_val b)) l


findEntry : Model -> Int -> Maybe Entry
findEntry model uid =
    find (\e -> e.id == uid) model.entries



-- ENCODE AND DECODE


modelEncoder : Model -> Json.Encode.Value
modelEncoder m =
    Json.Encode.object
        [ ( "entries", Json.Encode.list entryEncoder m.entries )
        , ( "field", Json.Encode.string m.field )
        , ( "uid", Json.Encode.int m.uid )
        , ( "visibility"
          , case m.visibility of
                Just vis ->
                    Json.Encode.string vis

                Nothing ->
                    Json.Encode.null
          )
        ]


modelDecoder : Json.Decode.Decoder Model
modelDecoder =
    Json.Decode.map6 Model
        (Json.Decode.field "entries" (Json.Decode.list entryDecoder))
        (Json.Decode.field "field" Json.Decode.string)
        (Json.Decode.field "uid" Json.Decode.int)
        (Json.Decode.field "visibility" (Json.Decode.nullable Json.Decode.string))
        (Json.Decode.succeed (Time.millisToPosix 0))
        -- time will be updated, anyway
        (Json.Decode.succeed NoEdit)


entryEncoder : Entry -> Json.Encode.Value
entryEncoder e =
    Json.Encode.object
        [ ( "description", Json.Encode.string e.description )
        , ( "completed", Json.Encode.bool e.completed )
        , ( "editing", Json.Encode.bool e.editing )
        , ( "id", Json.Encode.int e.id )
        , ( "doneAt"
          , Json.Encode.list
                (\x -> Time.posixToMillis x |> toFloat |> Json.Encode.float)
                e.doneAt
          )
        , ( "tags", Json.Encode.list Json.Encode.string e.tags )
        ]


entryDecoder : Json.Decode.Decoder Entry
entryDecoder =
    Json.Decode.map6 Entry
        (Json.Decode.field "description" Json.Decode.string)
        (Json.Decode.field "completed" Json.Decode.bool)
        (Json.Decode.field "editing" Json.Decode.bool)
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "doneAt" (Json.Decode.list (Json.Decode.float |> Json.Decode.map (\x -> round x |> Time.millisToPosix))))
        (Json.Decode.field "tags" (Json.Decode.list Json.Decode.string))
