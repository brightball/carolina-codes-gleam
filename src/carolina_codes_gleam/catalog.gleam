import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog

const speaker_cols = "slug, first_name, last_name, name, tagline, bio, company, location, photo_path, twitter_url, linkedin_url, website_url, github_url, featured"

const talk_cols = "slug, title, description, format, youtube_id, year, speaker_slug, languages, topics"

const year_sponsor_cols = "slug, name, website, logo_path, description, blurb, tier, featured, year, twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url"

const sponsor_cols = "slug, name, website, logo_path, description, twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url"

pub type Speaker {
  Speaker(
    slug: String,
    first_name: String,
    last_name: String,
    name: String,
    tagline: Option(String),
    bio: Option(String),
    company: Option(String),
    location: Option(String),
    photo_path: Option(String),
    twitter_url: Option(String),
    linkedin_url: Option(String),
    website_url: Option(String),
    github_url: Option(String),
    featured: Bool,
  )
}

pub type Talk {
  Talk(
    slug: String,
    title: String,
    description: Option(String),
    format: Option(String),
    youtube_id: Option(String),
    year: Int,
    speaker_slug: String,
    languages: List(String),
    topics: List(String),
  )
}

pub type YearRow {
  YearRow(year: Int, slug: String, name: String, status: String)
}

pub type YearSponsor {
  YearSponsor(
    slug: String,
    name: String,
    website: Option(String),
    logo_path: Option(String),
    description: Option(String),
    blurb: Option(String),
    tier: Option(String),
    featured: Bool,
    year: Int,
    twitter_url: Option(String),
    linkedin_url: Option(String),
    youtube_url: Option(String),
    instagram_url: Option(String),
    facebook_url: Option(String),
  )
}

pub type Sponsor {
  Sponsor(
    slug: String,
    name: String,
    website: Option(String),
    logo_path: Option(String),
    description: Option(String),
    twitter_url: Option(String),
    linkedin_url: Option(String),
    youtube_url: Option(String),
    instagram_url: Option(String),
    facebook_url: Option(String),
  )
}

pub type Sponsorship {
  Sponsorship(
    sponsor_slug: String,
    year: Int,
    tier: Option(String),
    blurb: Option(String),
    featured: Bool,
  )
}

fn text() -> decode.Decoder(String) {
  decode.one_of(decode.string, or: [
    decode.map(atom.decoder(), atom.to_string),
  ])
}

fn optional_text() -> decode.Decoder(Option(String)) {
  decode.optional(text())
}

fn string_list() -> decode.Decoder(List(String)) {
  decode.map(decode.optional(decode.list(text())), fn(value) {
    case value {
      Some(items) -> items
      None -> []
    }
  })
}

fn speaker_decoder() -> decode.Decoder(Speaker) {
  use slug <- decode.field(0, decode.string)
  use first_name <- decode.field(1, decode.string)
  use last_name <- decode.field(2, decode.string)
  use name <- decode.field(3, decode.string)
  use tagline <- decode.field(4, optional_text())
  use bio <- decode.field(5, optional_text())
  use company <- decode.field(6, optional_text())
  use location <- decode.field(7, optional_text())
  use photo_path <- decode.field(8, optional_text())
  use twitter_url <- decode.field(9, optional_text())
  use linkedin_url <- decode.field(10, optional_text())
  use website_url <- decode.field(11, optional_text())
  use github_url <- decode.field(12, optional_text())
  use featured <- decode.field(13, decode.bool)
  decode.success(Speaker(
    slug:,
    first_name:,
    last_name:,
    name:,
    tagline:,
    bio:,
    company:,
    location:,
    photo_path:,
    twitter_url:,
    linkedin_url:,
    website_url:,
    github_url:,
    featured:,
  ))
}

fn talk_decoder() -> decode.Decoder(Talk) {
  use slug <- decode.field(0, decode.string)
  use title <- decode.field(1, decode.string)
  use description <- decode.field(2, optional_text())
  use format <- decode.field(3, optional_text())
  use youtube_id <- decode.field(4, optional_text())
  use year <- decode.field(5, decode.int)
  use speaker_slug <- decode.field(6, decode.string)
  use languages <- decode.field(7, string_list())
  use topics <- decode.field(8, string_list())
  decode.success(Talk(
    slug:,
    title:,
    description:,
    format:,
    youtube_id:,
    year:,
    speaker_slug:,
    languages:,
    topics:,
  ))
}

fn year_decoder() -> decode.Decoder(YearRow) {
  use year <- decode.field(0, decode.int)
  use slug <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  use status <- decode.field(3, text())
  decode.success(YearRow(year:, slug:, name:, status:))
}

fn year_sponsor_decoder() -> decode.Decoder(YearSponsor) {
  use slug <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use website <- decode.field(2, optional_text())
  use logo_path <- decode.field(3, optional_text())
  use description <- decode.field(4, optional_text())
  use blurb <- decode.field(5, optional_text())
  use tier <- decode.field(6, optional_text())
  use featured <- decode.field(7, decode.bool)
  use year <- decode.field(8, decode.int)
  use twitter_url <- decode.field(9, optional_text())
  use linkedin_url <- decode.field(10, optional_text())
  use youtube_url <- decode.field(11, optional_text())
  use instagram_url <- decode.field(12, optional_text())
  use facebook_url <- decode.field(13, optional_text())
  decode.success(YearSponsor(
    slug:,
    name:,
    website:,
    logo_path:,
    description:,
    blurb:,
    tier:,
    featured:,
    year:,
    twitter_url:,
    linkedin_url:,
    youtube_url:,
    instagram_url:,
    facebook_url:,
  ))
}

fn sponsor_decoder() -> decode.Decoder(Sponsor) {
  use slug <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use website <- decode.field(2, optional_text())
  use logo_path <- decode.field(3, optional_text())
  use description <- decode.field(4, optional_text())
  use twitter_url <- decode.field(5, optional_text())
  use linkedin_url <- decode.field(6, optional_text())
  use youtube_url <- decode.field(7, optional_text())
  use instagram_url <- decode.field(8, optional_text())
  use facebook_url <- decode.field(9, optional_text())
  decode.success(Sponsor(
    slug:,
    name:,
    website:,
    logo_path:,
    description:,
    twitter_url:,
    linkedin_url:,
    youtube_url:,
    instagram_url:,
    facebook_url:,
  ))
}

fn sponsorship_decoder() -> decode.Decoder(Sponsorship) {
  use sponsor_slug <- decode.field(0, decode.string)
  use year <- decode.field(1, decode.int)
  use tier <- decode.field(2, optional_text())
  use blurb <- decode.field(3, optional_text())
  use featured <- decode.field(4, decode.bool)
  decode.success(Sponsorship(sponsor_slug:, year:, tier:, blurb:, featured:))
}

fn year_int_decoder() -> decode.Decoder(Int) {
  use year <- decode.field(0, decode.int)
  decode.success(year)
}

fn run(
  db: pog.Connection,
  query: pog.Query(t),
) -> Result(List(t), String) {
  case pog.execute(query, db) {
    Ok(pog.Returned(_count, rows)) -> Ok(rows)
    Error(err) -> Error(string.inspect(err))
  }
}

pub fn list_years(db: pog.Connection) -> Result(json.Json, String) {
  use rows <- result.try(
    pog.query("SELECT year, slug, name, status FROM v1_years ORDER BY year DESC")
    |> pog.returning(year_decoder())
    |> run(db, _),
  )
  Ok(json.object([#("data", json.array(rows, year_to_json))]))
}

pub fn list_speakers(
  db: pog.Connection,
  year: Option(Int),
) -> Result(json.Json, String) {
  case year {
    None -> {
      use rows <- result.try(
        pog.query(
          "SELECT "
          <> speaker_cols
          <> " FROM v1_speakers ORDER BY last_name, first_name",
        )
        |> pog.returning(speaker_decoder())
        |> run(db, _),
      )
      Ok(json.object([#("data", json.array(rows, speaker_to_json))]))
    }
    Some(y) -> {
      use speakers <- result.try(
        pog.query(
          "SELECT "
          <> speaker_cols
          <> " FROM v1_speakers WHERE slug IN (SELECT speaker_slug FROM v1_talks WHERE year = $1) ORDER BY last_name, first_name",
        )
        |> pog.parameter(pog.int(y))
        |> pog.returning(speaker_decoder())
        |> run(db, _),
      )
      use payloads <- result.try(
        list.try_map(speakers, fn(speaker) { year_speaker_json(db, speaker, y) }),
      )
      Ok(json.object([#("data", json.preprocessed_array(payloads))]))
    }
  }
}

pub fn speaker_by_slug(
  db: pog.Connection,
  slug: String,
) -> Result(Option(json.Json), String) {
  use speaker <- result.try(load_speaker(db, slug))
  case speaker {
    None -> Ok(None)
    Some(row) -> {
      use talks <- result.try(load_talks(db, slug, None))
      use years <- result.try(talk_years(db, slug))
      Ok(
        Some(json.object([
          #(
            "data",
            speaker_object(row, [
              #("talks", json.array(talks, talk_to_json)),
              #("years", json.array(years, json.int)),
            ]),
          ),
        ])),
      )
    }
  }
}

pub fn speaker_by_year(
  db: pog.Connection,
  year: Int,
  slug: String,
) -> Result(Option(json.Json), String) {
  use speaker <- result.try(load_speaker(db, slug))
  case speaker {
    None -> Ok(None)
    Some(row) -> {
      use talks <- result.try(load_talks(db, slug, Some(year)))
      case talks {
        [] -> Ok(None)
        _ -> {
          use years <- result.try(talk_years(db, slug))
          Ok(
            Some(json.object([
              #(
                "data",
                speaker_object(row, year_speaker_fields(year, talks, years)),
              ),
            ])),
          )
        }
      }
    }
  }
}

pub fn list_sponsors(
  db: pog.Connection,
  year: Option(Int),
) -> Result(json.Json, String) {
  case year {
    Some(y) -> {
      use rows <- result.try(
        pog.query(
          "SELECT "
          <> year_sponsor_cols
          <> " FROM v1_year_sponsors WHERE year = $1 ORDER BY name",
        )
        |> pog.parameter(pog.int(y))
        |> pog.returning(year_sponsor_decoder())
        |> run(db, _),
      )
      Ok(json.object([#("data", json.array(rows, year_sponsor_to_json))]))
    }
    None -> {
      use rows <- result.try(
        pog.query(
          "SELECT " <> sponsor_cols <> " FROM v1_sponsors ORDER BY name",
        )
        |> pog.returning(sponsor_decoder())
        |> run(db, _),
      )
      Ok(json.object([#("data", json.array(rows, sponsor_to_json))]))
    }
  }
}

pub fn sponsor_by_slug(
  db: pog.Connection,
  slug: String,
) -> Result(Option(json.Json), String) {
  use rows <- result.try(
    pog.query(
      "SELECT " <> sponsor_cols <> " FROM v1_sponsors WHERE slug = $1",
    )
    |> pog.parameter(pog.text(slug))
    |> pog.returning(sponsor_decoder())
    |> run(db, _),
  )
  case rows {
    [] -> Ok(None)
    [row, ..] -> {
      use sponsorships <- result.try(load_sponsorships(db, slug))
      Ok(
        Some(json.object([
          #(
            "data",
            sponsor_object(row, [
              #("sponsorships", json.array(sponsorships, sponsorship_to_json)),
            ]),
          ),
        ])),
      )
    }
  }
}

pub fn sponsor_by_year(
  db: pog.Connection,
  year: Int,
  slug: String,
) -> Result(Option(json.Json), String) {
  use rows <- result.try(
    pog.query(
      "SELECT "
      <> year_sponsor_cols
      <> " FROM v1_year_sponsors WHERE year = $1 AND slug = $2",
    )
    |> pog.parameter(pog.int(year))
    |> pog.parameter(pog.text(slug))
    |> pog.returning(year_sponsor_decoder())
    |> run(db, _),
  )
  case rows {
    [] -> Ok(None)
    [row, ..] -> {
      use years <- result.try(sponsor_years(db, slug))
      Ok(
        Some(json.object([
          #(
            "data",
            year_sponsor_object(row, [
              #("years", json.array(years, json.int)),
              #(
                "other_years",
                json.array(except_year(years, year), json.int),
              ),
            ]),
          ),
        ])),
      )
    }
  }
}

fn load_speaker(
  db: pog.Connection,
  slug: String,
) -> Result(Option(Speaker), String) {
  use rows <- result.try(
    pog.query(
      "SELECT " <> speaker_cols <> " FROM v1_speakers WHERE slug = $1",
    )
    |> pog.parameter(pog.text(slug))
    |> pog.returning(speaker_decoder())
    |> run(db, _),
  )
  case rows {
    [] -> Ok(None)
    [row, ..] -> Ok(Some(row))
  }
}

fn load_talks(
  db: pog.Connection,
  slug: String,
  year: Option(Int),
) -> Result(List(Talk), String) {
  let base =
    "SELECT "
    <> talk_cols
    <> " FROM v1_talks WHERE speaker_slug = $1"
  case year {
    None ->
      pog.query(base <> " ORDER BY year DESC")
      |> pog.parameter(pog.text(slug))
      |> pog.returning(talk_decoder())
      |> run(db, _)
    Some(y) ->
      pog.query(base <> " AND year = $2 ORDER BY year DESC")
      |> pog.parameter(pog.text(slug))
      |> pog.parameter(pog.int(y))
      |> pog.returning(talk_decoder())
      |> run(db, _)
  }
}

fn talk_years(db: pog.Connection, slug: String) -> Result(List(Int), String) {
  pog.query(
    "SELECT DISTINCT year FROM v1_talks WHERE speaker_slug = $1 ORDER BY year DESC",
  )
  |> pog.parameter(pog.text(slug))
  |> pog.returning(year_int_decoder())
  |> run(db, _)
}

fn sponsor_years(db: pog.Connection, slug: String) -> Result(List(Int), String) {
  pog.query(
    "SELECT DISTINCT year FROM v1_sponsorships WHERE sponsor_slug = $1 ORDER BY year DESC",
  )
  |> pog.parameter(pog.text(slug))
  |> pog.returning(year_int_decoder())
  |> run(db, _)
}

fn load_sponsorships(
  db: pog.Connection,
  slug: String,
) -> Result(List(Sponsorship), String) {
  pog.query(
    "SELECT sponsor_slug, year, tier, blurb, featured FROM v1_sponsorships WHERE sponsor_slug = $1 ORDER BY year DESC",
  )
  |> pog.parameter(pog.text(slug))
  |> pog.returning(sponsorship_decoder())
  |> run(db, _)
}

fn year_speaker_json(
  db: pog.Connection,
  speaker: Speaker,
  year: Int,
) -> Result(json.Json, String) {
  use talks <- result.try(load_talks(db, speaker.slug, Some(year)))
  use years <- result.try(talk_years(db, speaker.slug))
  Ok(speaker_object(speaker, year_speaker_fields(year, talks, years)))
}

fn year_speaker_fields(
  year: Int,
  talks: List(Talk),
  years: List(Int),
) -> List(#(String, json.Json)) {
  [
    #("year", json.int(year)),
    #("talks", json.array(talks, talk_to_json)),
    #("languages", json.array(uniq_tags(talks, fn(t) { t.languages }), json.string)),
    #("topics", json.array(uniq_tags(talks, fn(t) { t.topics }), json.string)),
    #("years", json.array(years, json.int)),
    #("other_years", json.array(except_year(years, year), json.int)),
  ]
}

pub fn uniq_tags(talks: List(Talk), pick: fn(Talk) -> List(String)) -> List(String) {
  talks
  |> list.flat_map(pick)
  |> list.filter(fn(value) { value != "" })
  |> unique()
}

pub fn unique(items: List(String)) -> List(String) {
  unique_loop(items, [], [])
}

fn unique_loop(
  items: List(String),
  seen: List(String),
  acc: List(String),
) -> List(String) {
  case items {
    [] -> list.reverse(acc)
    [item, ..rest] ->
      case list.contains(seen, item) {
        True -> unique_loop(rest, seen, acc)
        False -> unique_loop(rest, [item, ..seen], [item, ..acc])
      }
  }
}

fn except_year(years: List(Int), year: Int) -> List(Int) {
  list.filter(years, fn(value) { value != year })
}

fn year_to_json(row: YearRow) -> json.Json {
  json.object([
    #("year", json.int(row.year)),
    #("slug", json.string(row.slug)),
    #("name", json.string(row.name)),
    #("status", json.string(row.status)),
  ])
}

fn speaker_to_json(speaker: Speaker) -> json.Json {
  speaker_object(speaker, [])
}

fn speaker_object(
  speaker: Speaker,
  extra: List(#(String, json.Json)),
) -> json.Json {
  json.object(
    list.append(
      [
        #("slug", json.string(speaker.slug)),
        #("first_name", json.string(speaker.first_name)),
        #("last_name", json.string(speaker.last_name)),
        #("name", json.string(speaker.name)),
        #("tagline", json.nullable(speaker.tagline, json.string)),
        #("bio", json.nullable(speaker.bio, json.string)),
        #("company", json.nullable(speaker.company, json.string)),
        #("location", json.nullable(speaker.location, json.string)),
        #("photo_path", json.nullable(speaker.photo_path, json.string)),
        #("twitter_url", json.nullable(speaker.twitter_url, json.string)),
        #("linkedin_url", json.nullable(speaker.linkedin_url, json.string)),
        #("website_url", json.nullable(speaker.website_url, json.string)),
        #("github_url", json.nullable(speaker.github_url, json.string)),
        #("featured", json.bool(speaker.featured)),
      ],
      extra,
    ),
  )
}

fn talk_to_json(talk: Talk) -> json.Json {
  json.object([
    #("slug", json.string(talk.slug)),
    #("title", json.string(talk.title)),
    #("description", json.nullable(talk.description, json.string)),
    #("format", json.nullable(talk.format, json.string)),
    #("youtube_id", json.nullable(talk.youtube_id, json.string)),
    #("year", json.int(talk.year)),
    #("speaker_slug", json.string(talk.speaker_slug)),
    #("languages", json.array(talk.languages, json.string)),
    #("topics", json.array(talk.topics, json.string)),
  ])
}

fn year_sponsor_to_json(row: YearSponsor) -> json.Json {
  year_sponsor_object(row, [])
}

fn year_sponsor_object(
  row: YearSponsor,
  extra: List(#(String, json.Json)),
) -> json.Json {
  json.object(
    list.append(
      [
        #("slug", json.string(row.slug)),
        #("name", json.string(row.name)),
        #("website", json.nullable(row.website, json.string)),
        #("logo_path", json.nullable(row.logo_path, json.string)),
        #("description", json.nullable(row.description, json.string)),
        #("blurb", json.nullable(row.blurb, json.string)),
        #("tier", json.nullable(row.tier, json.string)),
        #("featured", json.bool(row.featured)),
        #("year", json.int(row.year)),
        #("twitter_url", json.nullable(row.twitter_url, json.string)),
        #("linkedin_url", json.nullable(row.linkedin_url, json.string)),
        #("youtube_url", json.nullable(row.youtube_url, json.string)),
        #("instagram_url", json.nullable(row.instagram_url, json.string)),
        #("facebook_url", json.nullable(row.facebook_url, json.string)),
      ],
      extra,
    ),
  )
}

fn sponsor_to_json(row: Sponsor) -> json.Json {
  sponsor_object(row, [])
}

fn sponsor_object(row: Sponsor, extra: List(#(String, json.Json))) -> json.Json {
  json.object(
    list.append(
      [
        #("slug", json.string(row.slug)),
        #("name", json.string(row.name)),
        #("website", json.nullable(row.website, json.string)),
        #("logo_path", json.nullable(row.logo_path, json.string)),
        #("description", json.nullable(row.description, json.string)),
        #("twitter_url", json.nullable(row.twitter_url, json.string)),
        #("linkedin_url", json.nullable(row.linkedin_url, json.string)),
        #("youtube_url", json.nullable(row.youtube_url, json.string)),
        #("instagram_url", json.nullable(row.instagram_url, json.string)),
        #("facebook_url", json.nullable(row.facebook_url, json.string)),
      ],
      extra,
    ),
  )
}

fn sponsorship_to_json(row: Sponsorship) -> json.Json {
  json.object([
    #("sponsor_slug", json.string(row.sponsor_slug)),
    #("year", json.int(row.year)),
    #("tier", json.nullable(row.tier, json.string)),
    #("blurb", json.nullable(row.blurb, json.string)),
    #("featured", json.bool(row.featured)),
  ])
}
