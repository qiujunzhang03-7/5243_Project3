# ============================================================
# Travel Planner – A/B Test App
# Version A: No progress bar (control)
# Version B: Progress bar / step indicator (treatment)
# Assignment: URL ?group=A or ?group=B; random 50/50 if absent
# Data logged to: data/events.csv
# ============================================================

library(shiny)
library(shinyjs)
library(cookies)         
library(googlesheets4)   

# ---- Google Sheets  -----------------------------------------

SHEET_ID <- "1ar-7UOqyDJ_0nS09AHbcOdh5a6xgrl3zFgmdfhFk0gg"

SECRET_PATH <- "secrets/gs_key.json"

if (file.exists(SECRET_PATH)) {
  tryCatch(
    gs4_auth(path = SECRET_PATH),
    error = function(e) {
      message("gs4_auth failed: ", e$message, ". Falling back to deauth.")
      gs4_deauth()
    }
  )
} else {
  message("WARNING: ", SECRET_PATH, " not found. ",
          "Cloud logging disabled; will write to local data/events.csv only.")
  gs4_deauth()
}

# ---- Helpers ---------------------------------------------------

# fallback
.write_local <- function(row) {
  if (!dir.exists("data")) dir.create("data", recursive = TRUE)
  f <- "data/events.csv"
  if (!file.exists(f)) write.csv(row, f, row.names = FALSE)
  else write.table(row, f, sep = ",", col.names = FALSE,
                   row.names = FALSE, append = TRUE, quote = TRUE)
}

log_event <- function(session_id, group, event, step, extra = "",
                      session = NULL) {   
  row <- data.frame(
    session_id = session_id,
    group      = group,
    event      = event,
    step       = as.integer(step),
    extra      = as.character(extra),
    timestamp  = format(Sys.time(), "%Y-%m-%d %H:%M:%OS3"),
    stringsAsFactors = FALSE
  )

  # Google Sheets
  cloud_ok <- FALSE
  if (file.exists(SECRET_PATH) && nzchar(SHEET_ID) &&
      !grepl("^PASTE", SHEET_ID)) {
    cloud_ok <- tryCatch({
      sheet_append(SHEET_ID, row, sheet = "events")
      TRUE
    }, error = function(e) {
      warning("Cloud log failed: ", e$message, call. = FALSE)
      FALSE
    })
  }
  if (!cloud_ok) .write_local(row)

  # Google Analytics
  if (!is.null(session)) {
    tryCatch({
      session$sendCustomMessage("ga_event", list(
        name   = gsub("[^A-Za-z0-9_]", "_", event),
        params = list(
          ab_group   = group %||% "unknown",
          step       = as.integer(step),
          session_id = session_id,
          extra      = as.character(extra)
        )
      ))
    }, error = function(e) NULL)  
  }
}

new_sid <- function() paste0(
  format(Sys.time(), "%Y%m%d%H%M%S"), "_",
  paste0(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")
)

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---- Activity database (50 per category) -----------------------

ACTS <- list(
  Food = c(
    "street food market crawl", "local cooking class",
    "signature restaurant tasting menu", "dawn fish market visit",
    "farm-to-table brunch at a countryside cafe", "dumpling-making workshop",
    "foraging and wild herb walk with a local chef", "wine and cheese tasting at a cellar",
    "harbour seafood tour with a fisherman", "pop-up night food festival",
    "neighbourhood bakery and pastry trail", "spice market and recipe card tour",
    "chocolate or coffee bean factory tour", "street taco and salsa trail",
    "ramen or noodle soup crawl across three shops", "artisan ice cream tasting tour",
    "truffle hunting walk in the countryside", "local market grocery shop and picnic",
    "cheese cave or winery cellar tour", "rooftop beekeeping and honey tasting",
    "fermentation and kimchi workshop", "sunrise dim sum with locals",
    "open-fire BBQ masterclass", "olive oil mill tour and tasting",
    "sake or mezcal distillery visit", "floating market boat food tour",
    "sourdough bread baking class", "street food photography and tasting walk",
    "fish and chips by the harbour", "local tapas bar crawl",
    "izakaya hopping evening", "traditional clay-pot cooking class",
    "mushroom foraging and omelette workshop", "local brewery behind-the-scenes tour",
    "traditional tea ceremony and tasting", "food truck festival afternoon",
    "sushi or sashimi masterclass", "underground supper club dinner",
    "mole or curry paste grinding workshop", "roadside barbecue pit visit",
    "market-to-table lunch with a home cook", "churros and chocolate morning",
    "cooking wild game with a ranger", "seafood shack oyster tasting",
    "fondue evening in a mountain chalet", "pasta-making afternoon with a nonna",
    "smoked meat and craft beer pairing", "street pho breakfast crawl",
    "baklava and Turkish delight workshop", "rooftop garden harvest dinner"
  ),

  History = c(
    "guided old quarter walking tour", "main archaeological museum",
    "fortress and citadel visit", "UNESCO heritage site exploration",
    "ancient ruins tour at sunrise", "colonial architecture walk",
    "underground city or cave dwelling tour", "royal palace and gardens visit",
    "war memorial and history centre", "old harbour and maritime museum",
    "medieval monastery day trip", "storytelling tour of the old city walls",
    "historic cemetery and legends walk", "traditional village open-air museum",
    "archive library rare manuscript viewing", "lost neighbourhood ghost tour at dusk",
    "vintage tram heritage route ride", "ancient aqueduct or canal walk",
    "oral history session with a local elder", "coin and artefact museum deep dive",
    "ancient lighthouse keeper tour", "roman bath or bathhouse visit",
    "revolutionary war battlefield walk", "old silk road caravanserai visit",
    "carved stone temple sunrise tour", "historic shipwreck glass-bottom boat tour",
    "cold war bunker underground tour", "indigenous sacred site guided visit",
    "feudal castle tower climb", "pirate cove and smugglers trail walk",
    "colosseum or amphitheatre evening tour", "ancient observatory star-map session",
    "gold rush ghost town exploration", "crusader castle rampart walk",
    "historic printing press demonstration", "ancient city walls sunset stroll",
    "Viking longship museum visit", "imperial garden ceremonial tour",
    "WWII resistance museum visit", "ancient trade port docks walk",
    "pre-Columbian pyramid climb at dawn", "alchemist quarter walking tour",
    "old stock exchange or guild hall tour", "traditional medicine pharmacy museum",
    "ancient road milestone trail walk", "abbey crypt and catacomb tour",
    "nomadic yurt and history camp visit", "opium or spice trade history trail",
    "slave trade heritage and memorial walk", "royal coronation chapel private tour"
  ),

  Nature = c(
    "sunrise hike to a scenic viewpoint", "botanical garden stroll",
    "national park day trip", "coastal cliff trail",
    "waterfall canyon hike", "river delta kayak tour",
    "birdwatching at a wetland reserve", "volcano or crater lake visit",
    "wildflower meadow walk", "sea turtle nesting beach visit",
    "firefly forest night walk", "mountain ridge trail with packed lunch",
    "tide pool and marine biology walk", "bamboo forest trail",
    "hot spring soak surrounded by jungle", "mangrove forest boat tour",
    "dawn dolphin-watching boat trip", "salt flat or desert dune walk at sunset",
    "cave or cenote swimming excursion", "night sky astronomy at a dark-sky site",
    "glacier hike with a mountain guide", "ancient redwood or baobab forest walk",
    "bog and moorland guided trek", "sea cliff seabird colony visit",
    "lava field walk at dusk", "alpine meadow picnic hike",
    "river otter and beaver watching at dawn", "coral reef snorkel morning",
    "canyon slot narrows hike", "geothermal geyser field walk",
    "mangrove paddling at high tide", "cactus desert dawn walk",
    "fox or lynx nocturnal spotting walk", "mountain lake wild swim",
    "aurora borealis waiting vigil", "whale watching catamaran trip",
    "tree canopy sky walk", "peat moss reserve guided walk",
    "night jungle torch walk", "sea glass and fossil beach hunt",
    "high alpine pass crossing day hike", "rewilding reserve wolf-track walk",
    "tide mill and estuary nature walk", "silent rainforest meditation walk",
    "volcanic hot mud pool visit", "dune boarding afternoon",
    "river gorge abseil and swim", "ice cave walk under a glacier",
    "dawn chorus bird recording walk", "sea kayak to a deserted island"
  ),

  Art = c(
    "contemporary art museum", "street mural and graffiti tour",
    "local gallery hopping", "artisan ceramics workshop",
    "glassblowing studio visit", "open-air sculpture park",
    "textile dyeing and weaving workshop", "live figure-drawing class",
    "printmaking atelier tour", "mosaic tile workshop",
    "public art treasure hunt across the city", "puppet theatre performance",
    "origami or paper-marbling workshop", "stained-glass studio tour",
    "street performance and busker circuit walk", "mural neighbourhood self-guided bike tour",
    "calligraphy class with a master", "jewellery forging workshop",
    "film photography darkroom session", "community mural painting morning",
    "botanical illustration class", "street photography zine workshop",
    "neon sign studio behind-the-scenes tour", "ink and woodblock printing studio",
    "wax batik fabric-making workshop", "life-size installation walk-through",
    "graffiti jam and legal wall session", "nude life drawing evening",
    "experimental sound art gallery", "video art and projection mapping event",
    "sand or snow sculpture workshop", "ikebana flower arrangement class",
    "lacquerware and gilding workshop", "shadow puppet making and performance",
    "urban sketching walk with a local artist", "fermentation art and science exhibition",
    "silk-screen printing T-shirt workshop", "textile mill and loom weaving tour",
    "museum late-night party event", "bronze casting studio afternoon",
    "manga or graphic novel drawing class", "stop-motion animation workshop",
    "traditional mask carving and painting", "mural festival walking guide",
    "sculpture foundry pouring session", "panoramic landscape oil-painting class",
    "concept car or industrial design museum", "traditional drum or sitar music workshop",
    "slow cinema screening and discussion", "outsider art gallery deep dive"
  ),

  Shopping = c(
    "artisan craft bazaar", "designer boutique district",
    "antique and vintage flea market", "local spice and goods market",
    "bookshop and independent record store trail", "night bazaar with street performers",
    "handmade jewellery workshop and market", "factory outlet shopping tour",
    "flower and plant market at dawn", "secondhand clothing market",
    "local farmers market with tastings", "souvenir and folk art fair",
    "textile and fabric district exploration", "toy and collectibles weekend fair",
    "herb and traditional medicine market walk", "custom tailor fitting session",
    "pottery and homeware market", "vinyl record hunting in side-street shops",
    "outdoor art print market", "local supermarket curiosity tour",
    "seasonal pop-up market", "auction house preview morning",
    "midnight electronics and gadget bazaar", "perfume blending atelier visit",
    "local rum, gin or spirits shop trail", "bespoke shoe cobbler commission",
    "floating barge antique market", "underground vintage fashion vault",
    "map and rare print dealer visit", "co-operative olive oil and honey shop",
    "recycled fashion swap meet", "old town pawnshop curiosity walk",
    "beeswax candle and soap makers market", "pop-up design graduate fair",
    "handmade paper and stationery shop trail", "local currency or stamp collectors fair",
    "organic and zero-waste grocery market", "skateboard and streetwear shop trail",
    "hand-rolled cigar factory shop visit", "nautical chart and compass antique dealer",
    "local fruit, nut and dried goods souk", "crystal and gemstone mineral market",
    "art nouveau homeware boutique trail", "military surplus and vintage workwear shop",
    "bonsai and terrarium specialist market", "lace and embroidery atelier visit",
    "morning flower auction hall tour", "designer archive and sample sale",
    "street calligraphy scroll commission", "handwoven rug and kilim gallery visit"
  ),

  Adventure = c(
    "zip-line canopy experience", "white-water kayaking excursion",
    "bicycle countryside tour", "rock climbing session",
    "paragliding tandem flight", "off-road jeep safari",
    "canyoning and abseiling half-day", "stand-up paddleboard rental",
    "via ferrata mountain route", "dune buggy desert ride",
    "night diving or snorkelling trip", "bungee jumping at a scenic bridge",
    "horse trekking through mountain trails", "coasteering sea cliff scramble",
    "jungle canopy walk on suspension bridges", "sea kayaking to a hidden sea cave",
    "skydiving tandem jump", "snowshoeing or glacier hike",
    "river tubing through a gorge", "sunset sailing on a catamaran",
    "motorbike tour through mountain roads", "free-solo bouldering morning",
    "cave rappelling and spelunking", "high-altitude snowboard run",
    "kite surfing lesson on an open beach", "dog sledding half-day",
    "paramotor flight over the coast", "cliff jumping at a secret lagoon",
    "urban parkour class with a local crew", "rafting class-IV rapids full day",
    "ice climbing frozen waterfall session", "night mountain bike descent",
    "freediving breath-hold course", "4WD sand dune bashing afternoon",
    "longbow archery in a forest clearing", "flyboard water jet session",
    "sunrise trail run up a volcano", "speed boat open-water blast",
    "obstacle course mud run", "slacklining over a gorge",
    "luge or bobsled track run", "deep-sea fishing overnight trip",
    "survival skills and fire-making bushcraft day", "off-piste powder ski day",
    "wakeboarding and water-ski lesson", "extreme caving in tight passages",
    "canyon swing launch", "drift trike or go-kart rally",
    "freediving to a shipwreck", "wingsuit proximity flight simulator"
  ),

  Relaxation = c(
    "morning thermal spa ritual", "beachside yoga session",
    "traditional hammam and scrub", "sunset meditation on a hilltop",
    "floatation tank and wellness centre", "forest bathing walk",
    "sound healing and gong bath", "private beach cabana afternoon",
    "tai chi class in a public park", "aromatherapy massage at a local spa",
    "slow boat river cruise with tea", "rooftop pool and infinity view afternoon",
    "sunrise qi gong by a lake", "silent retreat half-day at a monastery",
    "hot stone massage and sauna session", "watercolour painting in a peaceful garden",
    "sunset cruise with sparkling wine", "lakeside hammock reading afternoon",
    "cold plunge and fire sauna ritual", "guided breathing and mindfulness walk",
    "salt cave halotherapy session", "restorative yin yoga at dawn",
    "open-air hot tub under the stars", "aura photography and chakra reading",
    "private onsen soak in a mountain inn", "slow river drift on an inflatable",
    "hydrotherapy circuit at a thermal centre", "rooftop stargazing with hot chocolate",
    "pilates mat class by the sea", "crystal bowl meditation circle",
    "nature journaling walk in a quiet forest", "digital detox afternoon at a silent retreat",
    "garden labyrinth contemplative walk", "sunrise coastal walk with guided breathing",
    "sound bath in an ancient cave", "private museum early-access mindful visit",
    "slow train panoramic valley ride", "herb garden walk and herbal tea blending",
    "twilight paddleboard drift", "reiki session in a woodland studio",
    "full-moon beach fire ceremony", "ayurvedic treatment and massage",
    "lakeshore sketching afternoon", "Japanese garden silent sitting practice",
    "hot springs wild soak at dusk", "gratitude journaling retreat morning",
    "cloud-watching hilltop afternoon", "sensory deprivation tank session",
    "bee-garden mindfulness visit", "slow breakfast in a monastery garden"
  ),

  Nightlife = c(
    "rooftop bar with panoramic city views", "jazz bar in the old town",
    "night market exploration", "local live music venue",
    "underground cocktail bar tour", "salsa or tango social dance night",
    "open-air cinema screening", "craft beer taproom trail",
    "comedy club or improv night", "night harbour cruise with drinks",
    "casino evening or card room", "late-night ramen and street food walk",
    "speakeasy hidden bar hunt", "karaoke night with locals",
    "drum circle on the beach at sunset", "night food truck festival",
    "drag show or cabaret performance", "rooftop DJ and dance night",
    "pub quiz night at a local bar", "after-hours museum moonlight event",
    "burlesque or variety theatre show", "warehouse rave or techno club night",
    "flamenco or fado live performance dinner", "night cycling tour of lit-up landmarks",
    "poolside sunset DJ session", "firepit storytelling gathering",
    "lantern float or candlelight ceremony", "late-night book cafe reading circle",
    "open-mic poetry slam night", "rooftop movie under the stars",
    "swing dancing social night", "underground tango milonga",
    "night tour of neon sign districts", "absinthe bar historical tasting",
    "circus arts and acrobatics show", "folk music and dancing village fiesta",
    "supper club with live performance", "whisky blending masterclass evening",
    "pinball and arcade bar night", "night paddling glow kayak tour",
    "starlight dinner on a rooftop", "late-night izakaya crawl",
    "comedy magic show at a lounge bar", "ambient drone music concert",
    "candlelit opera or chamber concert", "night fishing off the pier with locals",
    "hammock bar sunset session", "live reggae beach bonfire night",
    "silent disco on a rooftop terrace", "salsa street dancing flash mob"
  ),

  Photography = c(
    "golden-hour shoot at the main landmark", "street photography in the old quarter",
    "sunrise shoot at a scenic viewpoint", "night skyline long-exposure session",
    "portrait session with locals at the market", "aerial drone shoot from a hilltop",
    "reflections shoot at a canal or lake at dusk", "architecture detail walk in the historic centre",
    "food photography workshop at a local restaurant", "rainy-day texture and colour street shoot",
    "blue-hour waterfront long-exposure", "factory or workshop documentary shoot",
    "misty morning fog valley shoot", "abandoned building urban exploration shoot",
    "wildlife macro photography in the forest", "colourful door and facade neighbourhood hunt",
    "festival crowd candid photography walk", "underwater photography snorkelling session",
    "shadow and light minimalist street shoot", "self-portrait project at iconic locations",
    "infrared landscape photography hike", "motion blur traffic trail night shoot",
    "double exposure portrait workshop", "light painting workshop in a dark studio",
    "tidal flat mirror reflection shoot at low tide", "storm-chasing weather shoot",
    "bokeh and depth-of-field flower garden workshop", "window light portraiture class",
    "rooftop 360-degree panoramic shoot", "market vendor series portrait project",
    "timelapse city rush-hour session", "old photo recreation historical walk",
    "drone coastal abstract shapes session", "cemetery and statuary fine-art shoot",
    "neon and rain reflection night walk", "construction site abstract geometry shoot",
    "public transport candid documentary session", "sunset silhouette beach shoot",
    "graffiti art colour theory walk and shoot", "hand and craft detail workshop",
    "smoke bomb portrait session in a park", "morning market fish and colour shoot",
    "industrial chimney stack and crane shoot", "slow shutter waterfall silky effect hike",
    "community mural backdrop portrait series", "monochrome alley and shadow walk",
    "vintage car boot fair candid series", "snowfall or rainfall blur street session",
    "bird-in-flight burst-mode morning", "star trail overnight long-exposure camp"
  ),

  Sports = c(
    "local football or basketball match", "surfing lesson on the main beach",
    "cycling along the coastal path", "morning run through the city park",
    "tennis clinic at a local club", "stand-up paddleboard race",
    "open-water swimming in a natural pool", "martial arts taster class",
    "beach volleyball tournament", "yoga and functional fitness class",
    "rowing or dragon boat session", "go-karting at a local circuit",
    "frisbee or spikeball on the beach", "morning bootcamp with locals",
    "cross-country trail run in the hills", "swimming in an Olympic outdoor pool",
    "skateboarding lesson at a local skate park", "archery range session",
    "bouldering at an indoor climbing wall", "sunrise swim at a wild lido",
    "ultimate frisbee pickup game in a park", "polo or equestrian lesson",
    "triathlon taster morning", "free diving breath-hold clinic",
    "traditional wrestling match observation", "foil surfing lesson",
    "local marathon or fun run participation", "crossfit open gym morning",
    "orienteering course in a forest", "handstand and calisthenics beach session",
    "bicycle polo pickup game", "flyweight boxing training session",
    "synchronized swimming taster class", "local cricket or baseball match",
    "parkour rooftop intro class", "spearfishing snorkel morning",
    "high-ropes adventure course", "capoeira class on the beach",
    "longboard skate tour of the city", "paddleboat race on a city lake",
    "gymnastics taster session at a local club", "axe throwing range session",
    "e-bike hill climb and descent tour", "dawn row on a river with a club",
    "slacklining and balance workshop", "traditional games afternoon with locals",
    "hurling or lacrosse taster session", "morning swim in an art deco lido",
    "cycling time trial on a closed circuit", "freediving pool session with coach"
  )
)

EVE_GENERIC <- c(
  "sunset walk along the waterfront", "rooftop dinner with city views",
  "local evening street food walk", "quiet dinner at a neighbourhood restaurant",
  "open-air concert or cultural show", "night stroll through the old town",
  "evening river or harbour cruise", "stargazing outside the city",
  "live folk music at a tavern", "night photography walk",
  "board game cafe evening", "cooking dinner with market ingredients",
  "sunset cocktails at a clifftop bar", "evening legend and ghost walking tour",
  "outdoor film screening in a park", "full-moon beach bonfire",
  "lantern release ceremony", "night cycling tour of the illuminated city",
  "karaoke dive bar with locals", "evening meditation on a hilltop",
  "slow dinner at a hidden courtyard restaurant", "wine bar and small plates evening",
  "jazz piano bar nightcap", "harbour promenade sunset ice cream walk",
  "open fire storytelling at a campsite", "traditional puppet show or street theatre",
  "rooftop telescope stargazing session", "hammock cocktail bar at sundown",
  "midnight souk or bazaar stroll", "artisan distillery evening tasting",
  "live acoustic session at a bookshop cafe", "silent disco on a rooftop",
  "candlelit cathedral or chapel concert", "ferry ride across the bay at dusk",
  "lakeside bonfire night", "evening paddle on a bioluminescent bay",
  "tasting menu at a chefs table", "local wine-and-cheese evening gathering",
  "sundowner cruise on a traditional vessel", "night market dumpling and beer evening",
  "steakhouse and whisky tasting dinner", "spoken word open mic at a cafe",
  "tea house traditional music evening", "lantern-lit alleyway walk in the old town",
  "fire dancer beach show", "cinema with locally made short films",
  "late-night bakery fresh bread tasting", "rooftop sunset yoga session",
  "improv comedy night at a local venue", "night market dim sum and beer crawl"
)

# ---- Itinerary generator ---------------------------------------

generate_itinerary <- function(city, budget, travel_style, interests,
                               days, accommodation, transport, pace) {
  budget <- max(50, as.numeric(budget))
  days   <- max(1,  as.numeric(days))
  tier   <- if (budget / days < 100) "budget"
            else if (budget / days < 350) "mid-range"
            else "luxury"

  acc_map <- list(
    Hostel = "a sociable hostel", Hotel = paste("a", tier, "hotel"),
    Airbnb = "a cozy Airbnb apartment", Resort = "a full-service resort",
    Camping = "a scenic campsite / glamping spot", Boutique = "a boutique hotel"
  )
  trans_map <- list(
    Flight = "fly in", Train = "take the train", Bus = "travel by coach",
    Car = "rent a car", Cruise = "arrive by cruise ship"
  )
  style_note <- switch(travel_style,
    Solo = "flying solo", Couple = "travelling as a couple",
    Family = "family trip", Group = "group travel", travel_style)

  if (length(interests) == 0) interests <- c("History", "Food")
  daily <- round(budget / days)

  # Build globally-shuffled no-repeat pools
  set.seed(nchar(city) * days * nchar(paste(sort(interests), collapse = "")))

  day_pool <- sample(unique(unlist(lapply(interests, function(k) {
    if (k %in% names(ACTS)) ACTS[[k]] else ACTS$History
  }))))
  eve_raw  <- if ("Nightlife" %in% interests) ACTS$Nightlife else EVE_GENERIC
  eve_pool <- sample(unique(eve_raw))

  # Sequential draw — each activity used at most once
  day_idx <- 1L
  eve_idx <- 1L

  next_day <- function() {
    if (day_idx > length(day_pool)) { day_pool <<- sample(day_pool); day_idx <<- 1L }
    act <- day_pool[day_idx]; day_idx <<- day_idx + 1L; act
  }
  next_eve <- function() {
    if (eve_idx > length(eve_pool)) { eve_pool <<- sample(eve_pool); eve_idx <<- 1L }
    act <- eve_pool[eve_idx]; eve_idx <<- eve_idx + 1L; act
  }

  lines <- c(
    paste0("## Your ", days, "-Day Trip to ", city),
    paste0("**Budget:** $", formatC(budget, format = "d", big.mark = ","),
           "  (~$", daily, " / day  \u2014  ", tier, ")"),
    paste0("**Style:** ", style_note, "  \u00b7  ", tolower(pace), " pace"),
    paste0("**Getting there:** ", trans_map[[transport]] %||% transport),
    paste0("**Stay:** ", acc_map[[accommodation]] %||% accommodation),
    paste0("**Interests:** ", paste(interests, collapse = "  \u00b7  ")),
    "---"
  )

  for (d in seq_len(days)) {
    lines <- c(lines,
      paste0("### Day ", d),
      paste0("\u2600\ufe0f **Morning** \u2014 ",   next_day()),
      paste0("\ud83c\udf24\ufe0f **Afternoon** \u2014 ", next_day()),
      paste0("\ud83c\udf19 **Evening** \u2014 ",   next_eve()),
      paste0("\ud83d\udcb0 *Est. ~$", daily, " today*"),
      ""
    )
  }

  lines <- c(lines, "---", paste0("\ud83c\udf1f *Have an amazing trip to ", city, "!*"))
  paste(lines, collapse = "\n")
}

# ---- CSS -------------------------------------------------------

css <- "
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700;900&family=DM+Sans:wght@400;500;600;700&display=swap');

:root {
  --teal:   #1B4D4A;
  --teal2:  #2A6B67;
  --amber:  #D97B3A;
  --cream:  #FAF7F2;
  --white:  #FFFFFF;
  --text:   #1C2B2A;
  --muted:  #6B7C7B;
  --border: #E3DDD5;
  --done:   #3BAA78;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: 'DM Sans', sans-serif;
  background: var(--cream);
  background-image:
    radial-gradient(ellipse at 18% 40%, rgba(27,77,74,.07) 0%, transparent 55%),
    radial-gradient(ellipse at 82% 15%, rgba(217,123,58,.07) 0%, transparent 50%);
  min-height: 100vh;
  padding: 0 16px 56px;
  color: var(--text);
}

/* Page header */
.ph { text-align: center; padding: 42px 20px 24px; }
.ph h1 {
  font-family: 'Playfair Display', serif;
  font-size: 2.5em; font-weight: 900;
  color: var(--teal); letter-spacing: -.5px; margin-bottom: 8px;
}
.ph p { color: var(--muted); font-size: .96em; }

/* Card */
.tp-card {
  max-width: 660px; margin: 0 auto;
  background: var(--white); border-radius: 24px;
  box-shadow: 0 12px 48px rgba(27,77,74,.13);
  overflow: hidden;
}

/* Progress bar */
.prog-wrap {
  padding: 20px 36px 10px;
  background: #F4F0EA;
  border-bottom: 1px solid var(--border);
}
.prog-track {
  display: flex; align-items: center;
  justify-content: space-between; position: relative;
}
.prog-rail {
  position: absolute; left: 18px; right: 18px;
  top: 50%; transform: translateY(-50%);
  height: 4px; background: var(--border); border-radius: 2px; z-index: 0;
}
.prog-fill {
  height: 100%; border-radius: 2px;
  background: linear-gradient(90deg, var(--teal), var(--amber));
  transition: width .45s cubic-bezier(.4,0,.2,1);
}
.prog-dot {
  width: 36px; height: 36px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-weight: 700; font-size: .82em;
  background: var(--border); color: #aaa;
  border: 3px solid var(--white); box-shadow: 0 0 0 2px var(--border);
  position: relative; z-index: 1; transition: all .3s ease;
}
.prog-dot.done  { background: var(--done); color: #fff; box-shadow: 0 0 0 2px #b8e8ce; }
.prog-dot.active {
  background: var(--teal); color: #fff;
  box-shadow: 0 0 0 3px rgba(27,77,74,.25); transform: scale(1.1);
}
.prog-labels { display: flex; justify-content: space-between; margin-top: 6px; }
.prog-lbl { font-size: .68em; color: #aaa; text-align: center; flex: 1; font-weight: 600; }
.prog-lbl.active { color: var(--teal); }

/* Step body */
.step-body { padding: 34px 40px 38px; }
.step-title {
  font-family: 'Playfair Display', serif;
  font-size: 1.6em; font-weight: 700;
  color: var(--teal); margin-bottom: 6px; line-height: 1.25;
}
.step-sub { color: var(--muted); font-size: .91em; margin-bottom: 24px; line-height: 1.5; }

/* Input overrides */
.form-group label { font-weight: 600; font-size: .87em; color: var(--teal); }
.form-control, input[type=number] {
  border: 2px solid var(--border) !important;
  border-radius: 12px !important;
  font-family: 'DM Sans', sans-serif !important;
  font-size: .97em !important;
  padding: 11px 15px !important;
  background: #FDFCF9 !important;
  color: var(--text) !important;
  transition: border-color .2s, box-shadow .2s !important;
}
.form-control:focus, input[type=number]:focus {
  border-color: var(--teal) !important;
  box-shadow: 0 0 0 4px rgba(27,77,74,.1) !important;
  outline: none !important;
}
select.form-control { background: #FDFCF9 !important; }
.radio label { font-weight: 500; font-size: .93em; color: var(--text); }
.radio input[type=radio] { accent-color: var(--teal); }

/* Slider */
.irs--shiny .irs-bar, .irs--shiny .irs-bar--single {
  background: var(--teal) !important; border-color: var(--teal) !important;
}
.irs--shiny .irs-handle > i:first-child { background: var(--teal) !important; }
.irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single {
  background: var(--teal) !important;
}

/* Chips */
.chips-wrap { display: flex; flex-wrap: wrap; gap: 9px; margin-top: 2px; }
.chip {
  padding: 9px 18px;
  border: 2px solid var(--border); border-radius: 50px;
  background: #FDFCF9; color: var(--muted);
  font-family: 'DM Sans', sans-serif;
  font-size: .88em; font-weight: 500;
  cursor: pointer; user-select: none; transition: all .18s ease;
}
.chip:hover { border-color: var(--teal2); color: var(--teal2); transform: translateY(-1px); }
.chip.on {
  background: var(--teal); border-color: var(--teal); color: #fff;
  box-shadow: 0 4px 12px rgba(27,77,74,.28); transform: translateY(-1px);
}

/* Buttons */
.btn-row { display: flex; gap: 11px; margin-top: 30px; }
.btn-next {
  flex: 1; padding: 14px;
  background: var(--teal); color: #fff;
  border: none; border-radius: 12px;
  font-family: 'DM Sans', sans-serif;
  font-size: .97em; font-weight: 700;
  cursor: pointer; letter-spacing: .2px;
  box-shadow: 0 4px 16px rgba(27,77,74,.22);
  transition: background .18s, transform .12s, box-shadow .18s;
}
.btn-next:hover {
  background: var(--teal2); transform: translateY(-2px);
  box-shadow: 0 7px 22px rgba(27,77,74,.28);
}
.btn-next:active { transform: translateY(0); }
.btn-back {
  padding: 14px 22px;
  background: transparent; color: var(--muted);
  border: 2px solid var(--border); border-radius: 12px;
  font-family: 'DM Sans', sans-serif;
  font-size: .97em; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.btn-back:hover { background: var(--cream); color: var(--text); border-color: #bbb; }

/* Itinerary */
.itin-box {
  background: #F5F1EB; border: 1px solid var(--border);
  border-radius: 14px; padding: 22px 26px;
  max-height: 440px; overflow-y: auto;
  font-size: .9em; line-height: 1.8; color: var(--text);
}
.itin-box h2 {
  font-family: 'Playfair Display', serif;
  font-size: 1.2em; color: var(--teal); margin-bottom: 8px;
}
.itin-box h3 {
  font-size: .78em; font-weight: 700; color: var(--amber);
  margin: 16px 0 5px; text-transform: uppercase; letter-spacing: 1px;
}
.itin-box hr { border: none; border-top: 1px solid var(--border); margin: 12px 0; }
.itin-box p  { margin: 3px 0; }

/* Version badge */
.ver-badge {
  position: fixed; top: 13px; right: 14px; z-index: 9999;
  background: rgba(27,77,74,.82); color: #fff;
  padding: 5px 14px; border-radius: 20px;
  font-size: .74em; font-weight: 700;
  font-family: 'DM Sans', sans-serif;
  backdrop-filter: blur(6px);
}
"

# ---- Constants -------------------------------------------------

STEP_LABELS <- c("City", "Style", "Budget", "Interests", "Transport", "Stay", "Days")
N_STEPS     <- length(STEP_LABELS)

INTERESTS <- c("🍜 Food", "🏛️ History", "🌿 Nature", "🎨 Art",
               "🛍️ Shopping", "🧗 Adventure", "🧘 Relaxation",
               "🎵 Nightlife", "📸 Photography", "⚽ Sports")

# ---- UI --------------------------------------------------------

ui <- cookies::add_cookie_handlers(fluidPage(
  useShinyjs(),
  tags$head(
    # --- Google Analytics 4 (GA4) --------------------------------
    tags$script(async = NA,
      src = "https://www.googletagmanager.com/gtag/js?id=G-TK74FHE2T7"),
    tags$script(HTML("
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', 'G-TK74FHE2T7', {
        'send_page_view': true,
        'anonymize_ip': true
      });

      Shiny.addCustomMessageHandler('ga_event', function(msg) {
        if (typeof gtag !== 'undefined') {
          gtag('event', msg.name, msg.params || {});
        }
      });

      Shiny.addCustomMessageHandler('ga_set_group', function(group) {
        if (typeof gtag !== 'undefined') {
          gtag('set', 'user_properties', {ab_group: group});
        }
      });
    ")),
    tags$style(HTML(css))
  ),

  div(class = "ver-badge", textOutput("ver_badge", inline = TRUE)),

  div(class = "ph",
    tags$h1("✈️ Travel Planner"),
    tags$p("Answer a few questions and get your personalised itinerary")
  ),

  fluidRow(
    column(10, offset = 1,
      div(class = "tp-card",
        uiOutput("progress_ui"),
        uiOutput("step_ui")
      )
    )
  )
))

# ---- Server ----------------------------------------------------

server <- function(input, output, session) {

  rv <- reactiveValues(
    group = NULL, session_id = NULL,
    step = 1L, step_ts = Sys.time(), completed = FALSE,
    city = "", travel_style = "Solo", pace = "Balanced",
    budget = 1000, interests = character(0),
    transport = "Flight", accommodation = "Hotel", days = 5
  )

  # Run once on session init. Using observeEvent with a one-shot trigger
  # prevents re-firing when cookies or other reactive values update.
  session_init_done <- reactiveVal(FALSE)

  observe({
    if (session_init_done()) return()

    q          <- parseQueryString(session$clientData$url_search)
    url_grp    <- if (!is.null(q$group) && q$group %in% c("A", "B")) q$group else NULL
    cookie_grp <- cookies::get_cookie("ab_group")

    if (!is.null(url_grp)) {
      rv$group <- url_grp
      cookies::set_cookie("ab_group", url_grp, expiration = 30)
    } else if (!is.null(cookie_grp) && cookie_grp %in% c("A", "B")) {
      rv$group <- cookie_grp
    } else {
      rv$group <- sample(c("A", "B"), 1)
      cookies::set_cookie("ab_group", rv$group, expiration = 30)
    }

    rv$session_id <- new_sid()
    rv$step_ts    <- Sys.time()

    session$sendCustomMessage("ga_set_group", rv$group)

    is_returning <- !is.null(cookie_grp) && is.null(url_grp)
    log_event(rv$session_id, rv$group, "session_start", 0,
              paste0("returning=", is_returning), session = session)

    session_init_done(TRUE)
  })

  output$ver_badge <- renderText({ req(rv$group); paste("Version", rv$group) })

  output$progress_ui <- renderUI({
    req(rv$group == "B")
    s   <- rv$step
    pct <- if (s > N_STEPS) 100 else round((s - 1) / (N_STEPS - 1) * 100)
    dots <- lapply(seq_len(N_STEPS), function(i) {
      cls <- if (i < s) "prog-dot done" else if (i == s) "prog-dot active" else "prog-dot"
      div(class = cls, if (i < s) "\u2713" else as.character(i))
    })
    lbls <- lapply(seq_len(N_STEPS), function(i)
      div(class = if (i == s) "prog-lbl active" else "prog-lbl", STEP_LABELS[i])
    )
    div(class = "prog-wrap",
      div(class = "prog-track",
        div(class = "prog-rail", div(class = "prog-fill", style = paste0("width:", pct, "%"))),
        dots
      ),
      div(class = "prog-labels", lbls)
    )
  })

  output$step_ui <- renderUI({
    req(rv$group)
    s <- rv$step

    lbl <- function(n, title)
      if (rv$group == "B") paste0("Step ", n, " / ", N_STEPS, " \u2014 ", title) else title

    nav <- function(back = TRUE, nxt = "Next \u2192") {
      if (back)
        div(class = "btn-row",
          tags$button("\u2190 Back", class = "btn-back",
            onclick = "Shiny.setInputValue('btn_back', Math.random())"),
          tags$button(nxt, class = "btn-next",
            onclick = "Shiny.setInputValue('btn_next', Math.random())")
        )
      else
        div(class = "btn-row",
          tags$button(nxt, class = "btn-next",
            onclick = "Shiny.setInputValue('btn_next', Math.random())")
        )
    }

    div(class = "step-body", switch(as.character(s),

      "1" = tagList(
        div(class = "step-title", lbl(1, "Where are you going? \U0001f5fa\ufe0f")),
        div(class = "step-sub",   "Enter your dream destination"),
        textInput("city_input", "City or destination", value = rv$city,
                  placeholder = "e.g. Tokyo, Paris, New York\u2026", width = "100%"),
        nav(back = FALSE)
      ),

      "2" = tagList(
        div(class = "step-title", lbl(2, "Who's travelling? \U0001f465")),
        div(class = "step-sub",   "Choose your travel style and trip pace"),
        selectInput("style_input", "Travel style", width = "100%",
          choices = c("Solo", "Couple", "Family", "Group"), selected = rv$travel_style),
        selectInput("pace_input", "Trip pace", width = "100%",
          choices = c("Relaxed", "Balanced", "Packed"), selected = rv$pace),
        nav()
      ),

      "3" = tagList(
        div(class = "step-title", lbl(3, "What's your budget? \U0001f4b0")),
        div(class = "step-sub",   "Total trip budget in USD"),
        numericInput("budget_input", "Total budget (USD)", value = rv$budget,
                     min = 50, max = 500000, step = 50, width = "100%"),
        nav()
      ),

      "4" = {
        chips <- lapply(INTERESTS, function(lbl_txt) {
          key <- trimws(sub("^\\S+\\s+", "", lbl_txt))
          cls <- if (key %in% rv$interests) "chip on" else "chip"
          tags$span(class = cls,
            onclick = sprintf("Shiny.setInputValue('toggle_chip','%s',{priority:'event'})", key),
            lbl_txt)
        })
        tagList(
          div(class = "step-title", lbl(4, "What are your interests? \U0001f3af")),
          div(class = "step-sub",   "Select all that apply"),
          div(class = "chips-wrap", chips),
          nav()
        )
      },

      "5" = tagList(
        div(class = "step-title", lbl(5, "How are you getting there? \U0001f68c")),
        div(class = "step-sub",   "Choose your main mode of transport"),
        radioButtons("transport_input", NULL, width = "100%",
          choiceNames  = c("\u2708\ufe0f Flight", "\U0001f682 Train", "\U0001f68c Bus / Coach",
                           "\U0001f697 Rental Car", "\U0001f6f3\ufe0f Cruise"),
          choiceValues = c("Flight", "Train", "Bus", "Car", "Cruise"),
          selected = rv$transport),
        nav()
      ),

      "6" = tagList(
        div(class = "step-title", lbl(6, "Where are you staying? \U0001f3e8")),
        div(class = "step-sub",   "Choose your accommodation type"),
        radioButtons("acc_input", NULL, width = "100%",
          choiceNames  = c("\U0001f3e8 Hotel", "\U0001f3e1 Airbnb / Apartment",
                           "\U0001f3d6\ufe0f Resort", "\U0001f3d5\ufe0f Camping / Glamping",
                           "\U0001f6cf\ufe0f Hostel", "\U0001f48e Boutique Hotel"),
          choiceValues = c("Hotel", "Airbnb", "Resort", "Camping", "Hostel", "Boutique"),
          selected = rv$accommodation),
        nav()
      ),

      "7" = tagList(
        div(class = "step-title", lbl(7, "How many days? \U0001f4c5")),
        div(class = "step-sub",   "Choose your trip duration"),
        sliderInput("days_input", "Number of days", min = 1, max = 10,
                    value = rv$days, step = 1, width = "100%"),
        nav(nxt = "\U0001f5fa\ufe0f Generate Itinerary")
      ),

      "8" = tagList(
        div(class = "step-title", "Your Itinerary is Ready! \U0001f389"),
        div(class = "step-sub",   paste("Personalised trip to", rv$city)),
        div(class = "itin-box", uiOutput("itin_html")),
        div(class = "btn-row",
          tags$button("\u2190 Edit Trip", class = "btn-back",
            onclick = "Shiny.setInputValue('btn_back', Math.random())"),
          tags$button("\U0001f504 Plan Another Trip", class = "btn-next",
            onclick = "Shiny.setInputValue('btn_restart', Math.random())")
        )
      )
    ))
  })

  output$itin_html <- renderUI({
    req(rv$step == 8L)
    txt   <- generate_itinerary(rv$city, rv$budget, rv$travel_style,
                                rv$interests, rv$days, rv$accommodation,
                                rv$transport, rv$pace)
    lines <- strsplit(txt, "\n")[[1]]
    els   <- lapply(lines, function(ln) {
      if      (grepl("^## ",  ln)) tags$h2(sub("^## ",  "", ln))
      else if (grepl("^### ", ln)) tags$h3(sub("^### ", "", ln))
      else if (grepl("^---",  ln)) tags$hr()
      else if (nchar(trimws(ln)) == 0) tags$span()
      else tags$p(ln)
    })
    do.call(tagList, els)
  })

  observeEvent(input$toggle_chip, {
    k <- input$toggle_chip
    rv$interests <- if (k %in% rv$interests) setdiff(rv$interests, k)
                    else c(rv$interests, k)
  })

  observeEvent(input$btn_next, {
    s    <- rv$step
    secs <- round(as.numeric(difftime(Sys.time(), rv$step_ts, units = "secs")), 1)
    ok   <- TRUE
    if (s == 1L) {
      v <- trimws(input$city_input %||% "")
      if (nchar(v) == 0) {
        showNotification("Please enter a destination.", type = "warning"); ok <- FALSE
      } else rv$city <- v
    } else if (s == 2L) {
      rv$travel_style <- input$style_input; rv$pace <- input$pace_input
    } else if (s == 3L) {
      b <- input$budget_input
      if (is.null(b) || is.na(b) || b < 50) {
        showNotification("Please enter a valid budget (min $50).", type = "warning"); ok <- FALSE
      } else rv$budget <- b
    } else if (s == 5L) {
      rv$transport     <- input$transport_input
    } else if (s == 6L) {
      rv$accommodation <- input$acc_input
    } else if (s == 7L) {
      rv$days <- input$days_input
    }
    if (!ok) return()
    log_event(rv$session_id, rv$group, "step_next", s,
              paste0("time_secs=", secs), session = session)
    rv$step    <- s + 1L
    rv$step_ts <- Sys.time()
    if (rv$step == 8L) {
      rv$completed <- TRUE
      log_event(rv$session_id, rv$group, "completed", 8, session = session)
    }
  })

  observeEvent(input$btn_back, {
    s    <- rv$step
    secs <- round(as.numeric(difftime(Sys.time(), rv$step_ts, units = "secs")), 1)
    log_event(rv$session_id, rv$group, "step_back", s,
              paste0("time_secs=", secs), session = session)
    if (s > 1L) { rv$step <- s - 1L; rv$step_ts <- Sys.time() }
  })

  observeEvent(input$btn_restart, {
    log_event(rv$session_id, rv$group, "restart", rv$step, session = session)
    rv$step <- 1L; rv$city <- ""; rv$travel_style <- "Solo"; rv$pace <- "Balanced"
    rv$budget <- 1000; rv$interests <- character(0)
    rv$transport <- "Flight"; rv$accommodation <- "Hotel"; rv$days <- 5
    rv$completed <- FALSE; rv$step_ts <- Sys.time()
    rv$session_id <- new_sid()
    log_event(rv$session_id, rv$group, "session_start", 0, session = session)
  })

  session$onSessionEnded(function() {
    sid  <- isolate(rv$session_id); grp <- isolate(rv$group)
    stp  <- isolate(rv$step);       comp <- isolate(rv$completed)
    ts0  <- isolate(rv$step_ts)
    dur_on_last <- round(as.numeric(difftime(Sys.time(), ts0, units = "secs")), 1)

    if (!is.null(sid) && !is.null(grp)) {
      log_event(sid, grp, "session_end", stp,
                paste0("completed=", comp, ";last_step_secs=", dur_on_last))
      if (!isTRUE(comp)) {
        log_event(sid, grp, "dropout", stp,
                  paste0("dropout_at_step=", stp, ";secs_on_step=", dur_on_last))
      }
    }
  })
}

# ---- Admin  -----------------------------

admin_ui <- fluidPage(
  titlePanel("A/B Test Admin Dashboard"),
  tags$p("Auto-refresh every 10 seconds."),
  fluidRow(
    column(4, wellPanel(
      h4("Sessions"),
      textOutput("stat_total"),
      textOutput("stat_a"),
      textOutput("stat_b")
    )),
    column(4, wellPanel(
      h4("Completion Rate"),
      textOutput("stat_comp_a"),
      textOutput("stat_comp_b")
    )),
    column(4, wellPanel(
      h4("Median Dropout Step"),
      textOutput("stat_drop_a"),
      textOutput("stat_drop_b")
    ))
  ),
  hr(),
  downloadButton("dl", "Download full CSV"),
  br(), br(),
  h4("Raw events (last 200 rows)"),
  div(style = "overflow-x:auto; font-size: 12px;", tableOutput("events_tbl"))
)

admin_server <- function(input, output, session) {
  ev <- reactivePoll(10000, session,
    checkFunc = function() Sys.time(),
    valueFunc = function() {
      tryCatch(
        as.data.frame(googlesheets4::read_sheet(SHEET_ID, sheet = "events")),
        error = function(e) data.frame()
      )
    })

  output$stat_total <- renderText({
    d <- ev(); if (nrow(d) == 0) return("Total sessions: 0")
    n <- length(unique(d$session_id[d$event == "session_start"]))
    paste("Total sessions:", n)
  })
  output$stat_a <- renderText({
    d <- ev(); if (nrow(d) == 0) return("A (control): 0")
    n <- length(unique(d$session_id[d$event == "session_start" & d$group == "A"]))
    paste("A (control):", n)
  })
  output$stat_b <- renderText({
    d <- ev(); if (nrow(d) == 0) return("B (treatment): 0")
    n <- length(unique(d$session_id[d$event == "session_start" & d$group == "B"]))
    paste("B (treatment):", n)
  })

  comp_rate <- function(d, g) {
    starts <- length(unique(d$session_id[d$event == "session_start" & d$group == g]))
    comps  <- length(unique(d$session_id[d$event == "completed"     & d$group == g]))
    if (starts == 0) return("—")
    paste0(comps, "/", starts, " (", round(100 * comps / starts, 1), "%)")
  }
  output$stat_comp_a <- renderText({ d <- ev(); if (nrow(d)==0) return("A: —"); paste("A:", comp_rate(d, "A")) })
  output$stat_comp_b <- renderText({ d <- ev(); if (nrow(d)==0) return("B: —"); paste("B:", comp_rate(d, "B")) })

  drop_median <- function(d, g) {
    dr <- d$step[d$event == "dropout" & d$group == g]
    if (length(dr) == 0) return("—")
    as.character(stats::median(as.integer(dr), na.rm = TRUE))
  }
  output$stat_drop_a <- renderText({ d <- ev(); if (nrow(d)==0) return("A: —"); paste("A:", drop_median(d, "A")) })
  output$stat_drop_b <- renderText({ d <- ev(); if (nrow(d)==0) return("B: —"); paste("B:", drop_median(d, "B")) })

  output$events_tbl <- renderTable({
    d <- ev(); if (nrow(d) == 0) return(data.frame(msg = "No data yet"))
    tail(d, 200)
  })

  output$dl <- downloadHandler(
    filename = function() paste0("ab_events_", Sys.Date(), ".csv"),
    content  = function(file) write.csv(ev(), file, row.names = FALSE)
  )
}

ui_router <- function(req) {
  q <- parseQueryString(req$QUERY_STRING)
  if (!is.null(q$admin) && q$admin == "1") admin_ui else ui
}

server_router <- function(input, output, session) {
  # url_search is reactive; isolate() reads it once without dependency
  q <- isolate(parseQueryString(session$clientData$url_search))
  if (!is.null(q$admin) && q$admin == "1") {
    admin_server(input, output, session)
  } else {
    server(input, output, session)
  }
}

shinyApp(ui = ui_router, server = server_router)
