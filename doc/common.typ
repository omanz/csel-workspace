#import "/lib/hei-synd-report/lib/template-report.typ": *

#let question-color = rgb("#00c853")
#let questionbox(body) = {
  align(left,
    rect(
      stroke: (left: question-color + 4pt, rest: luma(180) + 0.1pt),
      radius: (left: 0pt, right: 4pt),
      fill: luma(245),
      inset: (left: 5pt, top: 5pt, right: 10pt, bottom: 5pt),
      width: 100%,
    )[
      #table(
        stroke: none,
        align: left + horizon,
        columns: (auto, auto),
        box(
          width:1.8em,
          height: 1.8em,
        )[
          #align(center + horizon)[
            #image(
              bytes(```xml
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 0 0" fill="#00c853">
                <path d="m15.07 11.25-.9.92C13.45 12.89 13 13.5 13 15h-2v-.5c0-1.11.45-2.11 1.17-2.83l1.24-1.26c.37-.36.59-.86.59-1.41a2 2 0 0 0-2-2 2 2 0 0 0-2 2H8a4 4 0 0 1 4-4 4 4 0 0 1 4 4 3.2 3.2 0 0 1-.93 2.25M13 19h-2v-2h2M12 2A10 10 0 0 0 2 12a10 10 0 0 0 10 10 10 10 0 0 0 10-10c0-5.53-4.5-10-10-10"/>
              </svg>
              ```.text),
              format: "svg",
              width: 1.8em,
            )
          ]
        ],
        [#body]
      )
    ]
  )
}

#let edit-color = rgb("#2196F3")
#let editbox(body) = {
  align(left,
    rect(
      stroke: (left: edit-color + 4pt, rest: luma(180) + 0.1pt),
      radius: (left: 0pt, right: 4pt),
      fill: luma(245),
      inset: (left: 5pt, top: 5pt, right: 10pt, bottom: 5pt),
      width: 100%,
    )[
      #table(
        stroke: none,
        align: left + horizon,
        columns: (auto, auto),
        box(
          width:1.8em,
          height: 1.8em,
        )[
          #align(center + horizon)[
            #image(
              bytes(```xml
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 0 0" fill="#2196F3">
                <path d="M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2m3.1 5.07c.14 0 .28.05.4.16l1.27 1.27c.23.22.23.57 0 .78l-1 1-2.05-2.05 1-1c.1-.11.24-.16.38-.16m-1.97 1.74 2.06 2.06-6.06 6.06H7.07v-2.06z"/>
              </svg>
              ```.text),
              format: "svg",
              width: 1.8em,
            )
          ]
        ],
        [#body]
      )
    ]
  )
}
