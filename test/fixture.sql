CREATE TABLE v1_years (
  year integer NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  status text NOT NULL
);

CREATE TABLE v1_speakers (
  slug text NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  name text NOT NULL,
  tagline text,
  bio text,
  company text,
  location text,
  photo_path text,
  twitter_url text,
  linkedin_url text,
  website_url text,
  github_url text,
  featured boolean NOT NULL
);

CREATE TABLE v1_talks (
  slug text NOT NULL,
  title text NOT NULL,
  description text,
  format text,
  youtube_id text,
  year integer NOT NULL,
  speaker_slug text NOT NULL,
  languages text[] NOT NULL,
  topics text[] NOT NULL
);

CREATE TABLE v1_sponsors (
  slug text NOT NULL,
  name text NOT NULL,
  website text,
  logo_path text,
  description text,
  twitter_url text,
  linkedin_url text,
  youtube_url text,
  instagram_url text,
  facebook_url text
);

CREATE TABLE v1_year_sponsors (
  slug text NOT NULL,
  name text NOT NULL,
  website text,
  logo_path text,
  description text,
  blurb text,
  tier text,
  featured boolean NOT NULL,
  year integer NOT NULL,
  twitter_url text,
  linkedin_url text,
  youtube_url text,
  instagram_url text,
  facebook_url text
);

CREATE TABLE v1_sponsorships (
  sponsor_slug text NOT NULL,
  year integer NOT NULL,
  tier text,
  blurb text,
  featured boolean NOT NULL
);

INSERT INTO v1_years (year, slug, name, status) VALUES
  (2026, '2026', 'Carolina Code 2026', 'current'),
  (2025, '2025', 'Carolina Code 2025', 'past'),
  (2024, '2024', 'Carolina Code 2024', 'past');

INSERT INTO v1_speakers (
  slug, first_name, last_name, name, tagline, bio, company, location,
  photo_path, twitter_url, linkedin_url, website_url, github_url, featured
) VALUES
  ('ada-lovelace', 'Ada', 'Lovelace', 'Ada Lovelace', 'Analyst', 'First programmer', 'Analytical Engines', 'London', '/photos/ada.jpg', NULL, NULL, 'https://ada.example', 'https://github.com/ada', true),
  ('grace-hopper', 'Grace', 'Hopper', 'Grace Hopper', 'Compiler', 'COBOL', 'Navy', 'New York', NULL, NULL, NULL, NULL, NULL, true),
  ('katherine-johnson', 'Katherine', 'Johnson', 'Katherine Johnson', 'Math', 'Trajectories', 'NASA', 'Hampton', NULL, NULL, NULL, NULL, NULL, false),
  ('barbara-liskov', 'Barbara', 'Liskov', 'Barbara Liskov', 'Types', 'Substitution', 'MIT', 'Boston', NULL, NULL, NULL, NULL, NULL, false);

INSERT INTO v1_talks (
  slug, title, description, format, youtube_id, year, speaker_slug, languages, topics
) VALUES
  ('ada-2026', 'Notes on the engine', 'A talk', 'talk', 'yt-ada-2026', 2026, 'ada-lovelace', ARRAY['gleam', 'erlang']::text[], ARRAY['systems']::text[]),
  ('ada-2025', 'Notes on notation', NULL, 'talk', NULL, 2025, 'ada-lovelace', ARRAY['gleam']::text[], ARRAY['types']::text[]),
  ('grace-2026', 'Compilers', 'A talk', 'talk', NULL, 2026, 'grace-hopper', ARRAY['cobol']::text[], ARRAY['compilers']::text[]),
  ('grace-2024', 'History', NULL, 'talk', NULL, 2024, 'grace-hopper', ARRAY['cobol']::text[], ARRAY[]::text[]),
  ('kj-2026', 'Trajectories', 'A talk', 'talk', NULL, 2026, 'katherine-johnson', ARRAY['fortran']::text[], ARRAY['math']::text[]),
  ('liskov-2025', 'Substitution', NULL, 'talk', NULL, 2025, 'barbara-liskov', ARRAY['clu']::text[], ARRAY['types']::text[]);

INSERT INTO v1_sponsors (
  slug, name, website, logo_path, description, twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url
) VALUES
  ('acme', 'Acme', 'https://acme.example', '/logos/acme.png', 'Widgets', NULL, NULL, NULL, NULL, NULL),
  ('globex', 'Globex', 'https://globex.example', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO v1_year_sponsors (
  slug, name, website, logo_path, description, blurb, tier, featured, year,
  twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url
) VALUES
  ('acme', 'Acme', 'https://acme.example', '/logos/acme.png', 'Widgets', 'Thanks', 'gold', true, 2026, NULL, NULL, NULL, NULL, NULL),
  ('acme', 'Acme', 'https://acme.example', '/logos/acme.png', 'Widgets', NULL, 'silver', false, 2025, NULL, NULL, NULL, NULL, NULL),
  ('globex', 'Globex', 'https://globex.example', NULL, NULL, NULL, 'bronze', false, 2026, NULL, NULL, NULL, NULL, NULL);

INSERT INTO v1_sponsorships (sponsor_slug, year, tier, blurb, featured) VALUES
  ('acme', 2026, 'gold', 'Thanks', true),
  ('acme', 2025, 'silver', NULL, false),
  ('globex', 2026, 'bronze', NULL, false);
