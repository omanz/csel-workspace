#import "/lib/hei-synd-report/lib/template-report.typ": *
#import "/lib/hei-synd-report/lib/pages-report.typ": *

//-------------------------------------
// Document options
//
#let option = (
  type : sys.inputs.at("type", default:"draft"),    // [draft|final]
  lang : sys.inputs.at("lang", default:"fr"),       // [en|fr|de]
)
//-------------------------------------
// Optional generate titlepage image
//
#import "@preview/fractusist:0.3.2":*  // only for the generated images
#let hash-text(text) = {
  let sum = 0
  for b in bytes(text) {
    sum += int(b)
  }
  sum
}
#let seed = hash-text(str("https://mse-csel.github.io/website/assignments/programmation-systeme/fichiers/"))

#let iterations = 10 + calc.rem(seed, 5)        // [10;14]
#let step = 3 + calc.rem(seed, 4)               // [3;6]

#let titlepage_logo= dragon-curve(
  iterations,
  step-size: step,
  stroke: stroke(
    paint: gradient.radial(..color.map.rocket),
    thickness: 1pt, join: "round"
  ),
)

//-------------------------------------
// Metadata of the document
//
#let doc= (
  title    : [*Programmation système Linux et Optimisation système Linux*],
  abbr     : "MA_CSEL",
  subtitle : none,
  url      : "https://mse-csel.github.io/website/assignments/programmation-systeme/fichiers/",
  github   : "https://github.com/omanz/csel-workspace",
  location : "Fribourg",

  logos: (
    tp_topleft  : image("resources/img/mse-small-margin.svg", height: 0.6cm),
    tp_topright : image("resources/img/heia-fr-logo.svg", height: 1.3cm),
    tp_main     : titlepage_logo,
    header      : image("resources/img/mse-small-margin.svg", width: 3.0cm),
  ),
  authors: (
    (
      name        : "Olivia Manz",
      abbr        : "Olivia Manz",
      email       : "olivia.manz@hmaster.hes.so.ch",
    ),
    (
      name        : "Yoann Archier",
      abbr        : "Yoann Archier",
      email       : "yoann.archier@master.hes-so.ch",
    )
  ),
  school: (
    name            : "HES-SO Master",
    url             : "https://www.hes-so.ch/en/master",
    major           : "Engineering (MSE)",
    major_url       : "https://www.hes-so.ch/en/master/hes-so-master/programmes/engineering-mse",
    orientation     : "Computer science",
    orientation_url : "https://www.hes-so.ch/en/field-of-study/ia/mse/cs",
  ),
  course: (
    name     : "Construction de systèmes embarqués sous Linux",
    url      : "https://mse-csel.github.io/website/",
    prof     : "Jacques Supcik",
    email    : "jacques.supcik@hefr.ch",
    class    : none,
    semester : "Semestre printemps 2026",
  ),
  keywords : ("Typst", "Template", "Report", "HES-SO", "Engineering"),
  version  : "v0.1.0",
)

#let date= datetime.today()

//-------------------------------------
// Settings
//
#let display = (
  gradient: false,
)

#let tableof = (
  toc: true,
  tof: false,
  tot: false,
  tol: false,
  toe: false,
  maxdepth: 3,
)

#let gloss    = true
#let appendix = false
#let bib = (
  display : false,
  path  : "/tail/bibliography.bib",
  style : "ieee", //"apa", "chicago-author-date", "chicago-notes", "mla"
)

#let fonts = (
  text: "Libertinus Serif",
  mono: "DejaVu Sans Mono",
  math: "New Computer Modern Math",
)
