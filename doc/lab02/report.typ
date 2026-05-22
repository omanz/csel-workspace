#import "metadata.typ": *
//#import "tail/bibliography.typ": *
//#import "tail/glossary.typ": *
//#show:make-glossary
//#register-glossary(entry-list)

//-------------------------------------
// Template config
//
#show: report.with(
  option: option,
  doc: doc,
  date: date,
  display: display,
  tableof: tableof,
  fonts: fonts,
)

//-------------------------------------
// Content
//
#include "main/01-programmation.typ"
#include "main/02-optimisation.typ"
#include "main/02-outilsperf.typ"
#include "main/03-feedback.typ"
#include "main/04-annexes.typ"


//#heading(numbering:none, outlined: false)[] <sec:end>

//-------------------------------------
// Glossary
//
//#make_glossary(gloss:gloss, title:i18n("gloss-title", lang: option.lang))

//-------------------------------------
// Bibliography
//
//#make_bibliography(
//  bib: (display: true, path: "/lab02/tail/bibliography.bib", style: "ieee"),
//  title: i18n("bib-title", lang: option.lang)
//)


//-------------------------------------
// Appendix
//
#if appendix == true {[
  #counter(heading).update(0)
  #set heading(numbering:"A")
  #include "/tail/a-appendix.typ"
]}
