// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

#import "@preview/pubmatter:0.2.1"
#import "@preview/wordometer:0.1.4": word-count, total-words, total-characters

#let lepub(
  frontmatter: (),
  options: (),
  kind: none,
  // The path to a bibliography file if you want to cite some external works.
  page-start: none,
  max-page: none,
  // The paper's content.
  body
) = {

  // Here we need to specify the default options in case none are being provided
  let default-options = (
      theme-color: "#2453A1",
      font-body: "libertinus serif",
      font-body-size: 9pt,
      line-spacing: 0.65em,
      line-numbers: false,
      margin-side: "right",
      section-numbering: "1.1.1",
      section-numbering-last: false,
      logo: none,
      logo-position: top,
      bibliography: none,
      bibliography-style: "ieee",
      date-submitted: none,
      date-received: none,
      date-accepted: none,
      date-published: none,
      paper-size: "us-letter",
      parts: (
        data-availability: none,
        funding: none
        ),
      word-count: false
    )

  if (type(options) == array) {
    options = options.to-dict()
  }

  let options = default-options + options

  // Line spacing
  if (type(options.line-spacing) == str) {
    if (options.line-spacing == "single") {
      options.line-spacing = 0.65em
    } else if (options.line-spacing == "onehalf") {
      options.line-spacing = 0.975em
    } else if (options.line-spacing == "double") {
      options.line-spacing = 1.3em
    }
  }

  // Alignment
  options.side-width = 27%
  options.margin-side = str(options.margin-side)
  if (options.margin-side == "left") {
    options.margin-side-align = left
    options.margin-shift = -33%
    options.margin-shift-logo = -33%
    if (options.line-numbers == true) {
      options.side-width = 24%
      // options.number-clearance = 8pt
    }
  } else if (options.margin-side == "right") {
    options.margin-side-align = right
    options.margin-shift = 5.2%
    options.margin-shift-logo = 32%
  }

  // Logo placement
  if (options.logo-position == top) {
    options.logo-v-adjustment = -10pt
  } else if (options.logo-position == bottom) {
    options.logo-v-adjustment = -70pt
  }

  // Load frontmatter
  let fm = pubmatter.load(frontmatter)

  // Process dates
  let dates;
  if ("date" in fm and type(fm.date) == datetime) {
    dates = (
      (title: "Submitted", date: fm.date),
      )
  } else {
    dates = date
  }

  // Process colors
  let theme-color = rgb(options.theme-color.replace("\\", ""))

  // Set document metadata.
  set document(title: fm.title, author: fm.authors.map(author => author.name))
  let theme = (color: theme-color, font: options.font-body)
  if (page-start != none) {counter(page).update(page-start)}
  state("THEME").update(theme)

  show: word-count
  let n-words = total-words
  let n-characters = total-characters

  set page(
    paper: options.paper-size,
    margin: (options.margin-side: 25%),
    header: pubmatter.show-page-header(fm),
    footer: block(
      width: 100%,
      stroke: (top: 1pt + gray),
      inset: (top: 8pt, right: 2pt),
      context [
        #set text(
          font: theme.font, 
          size: 9pt, 
          fill: gray.darken(50%)
          )
        #pubmatter.show-spaced-content((
          if("venue" in fm) {emph(fm.venue)},
          if("date" in fm and fm.date != none) {fm.date.display("[month repr:long] [day], [year]")}
        ))
        #h(1fr)
        #counter(page).display()
      ]
    ),
  )

  show link: it => [#text(fill: theme.color)[#it]]
  show ref: it => {
    if (it.element == none)  {
      // This is a citation showing 2024a or [1]
      show regex("([\d]{1,4}[a-z]?)"): it => text(fill: theme.color, it)
      it
      return
    }
    // The rest of the references, like `Figure 1`
    set text(fill: theme.color)
    it
  }

  // Set the body font.
  set text(
    font: options.font-body, 
    size: options.font-body-size
  )
  // Configure equation numbering and spacing.
  set math.equation(numbering: "(1)")
  show math.equation: set block(spacing: 1em)

  // =============================== //
  // =========== Lists ============= //
  // =============================== //
  set enum(indent: 10pt, body-indent: 9pt)
  set list(indent: 10pt, body-indent: 9pt)

  // =============================== //
  // ========== Headings =========== //
  // =============================== //

  set heading(numbering: options.section-numbering)
  show heading: it => context {
    let loc = here()
    // Find out the final number of the heading counter.
    let levels = counter(heading).at(loc)
    let level-patterns = options.section-numbering.split(".")
    set text(10pt, weight: 400)
    if it.level == 1 [
      // First-level headings are centered smallcaps.
      // We don't want to number of the acknowledgment section.
      #let is-ack = it.body in ([Acknowledgements], [Declaration of Competing Interest])
      // #set align(center)
      #set text(if is-ack { 10pt } else { 12pt }, weight: if is-ack { "regular" } else { "bold" })
      // #show: smallcaps
      #show: block.with(above: 20pt, below: 13.75pt, sticky: true)
      #if it.numbering != none and not is-ack {
        numbering(level-patterns.at(0), levels.at(0))
        [.]
        h(7pt, weak: true)
      }
      #it.body
    ] else if it.level == 2 [
      // Second-level headings are run-ins.
      #set par(first-line-indent: 0pt)
      #set text(weight: "semibold")
      #show: block.with(above: 15pt, below: 13.75pt, sticky: true)
      #if it.numbering != none {
        if options.section-numbering-last == false {
          numbering(options.section-numbering, ..levels) 
          } else { 
          numbering(level-patterns.at(1), levels.at(1))
        } 
        // [.]
        h(7pt, weak: true)
      }
      #it.body
    ] else [
      // Third level headings are run-ins too, but different.
      #show: block.with(above: 15pt, below: 13.75pt, sticky: true)
      #set text(style: "italic")
      #if it.level == 3 and it.numbering != none {
        if options.section-numbering-last == false {
          numbering(options.section-numbering, ..levels) 
          } else { 
          numbering(level-patterns.at(2), levels.at(2))
        } 
        // [. ]
        h(5pt, weak: true)
      }
      #it.body
    ]
  }

  // =============================== //
  // ======== Logo placement ======= //
  // =============================== //
  if options.at("logo", default: none) != none {
    place(
      options.logo-position + options.margin-side-align,
      dx: options.margin-shift-logo,
      float: false,
      box(
        width: 27%,
        {
          if (type(options.logo) == content) {
            options.logo
          } else {
            image(options.logo, width: 100%)
          }
        },
      ),
    )
  }

  // Creates custom contexts
  let left-caption(it) = context {
    set text(size: 8pt)
    set align(left)
    set par(justify: true)
    text(weight: "bold")[#it.supplement #it.counter.display(it.numbering)]
    "."
    h(4pt)
    set text(fill: black.lighten(20%), style: "italic")
    it.body
  }

  // =============================== //
  // ====== Title and Subtitle ===== //
  // =============================== //
  pubmatter.show-title-block(fm)

  // =============================== //
  // ======== Margin matter ======== //
  // =============================== //
  let corresponding = fm.authors.filter((author) => "email" in author).at(0, default: none)
  let margin = (

    // == Corresponding author == //
    if corresponding != none {
      (
        title: "Correspondence to",
        content: [
          #corresponding.name\
          #link("mailto:" + corresponding.email)[#corresponding.email]
        ],
      )
    },
    (
      title: [License #h(1fr) #pubmatter.show-license-badge(fm)],
      content: [
        #set par(justify: true)
        #set text(size: 7pt)
        #pubmatter.show-copyright(fm)
      ]
    ),

    // == Data Availability == //
    if options.at("parts", default: none) != none {(
      if "data-availability" in options.parts {(
        if options.parts.data-availability != none {(
          title: "Data Availability",
          content: [
            #set par(justify: true)
            #set text(size: 7pt)
            #options.parts.data-availability
          ],
        )}
      )}
    )},

    // == Funding == //
    if options.at("parts", default: none) != none {(
      if "funding" in options.parts {(
        if options.parts.funding != none {(
        title: "Funding",
        content: [
          #set par(justify: true)
          #set text(size: 7pt)
          #options.parts.funding
          ],
        )}
      )}
    )},

    // Word count
    if options.at("word-count", default: false) == true {(
      title: "Word count",
      content: [
        #set par(justify: true)
        #set text(size: 7pt)
        Words: #n-words \
        Characters: #n-characters
      ]
    )}
  ).filter((m) => m != none)

  // Margin matter placement
  place(
    options.margin-side-align + bottom,
    dx: options.margin-shift,
    dy: options.logo-v-adjustment,
    place( // Nested `place` to ensure that text can be left-aligned when in right margin
      left + bottom,
      box(width: options.side-width, {
        set text(font: theme.font)
        if (kind != none) {
          show par: set par(spacing: 0em)
          text(11pt, fill: theme.color, weight: "semibold", smallcaps(kind))
          parbreak()
        }
        if (dates != none) {
          let formatted-dates

          grid(columns: (40%, 60%), gutter: 7pt,
            ..dates.zip(range(dates.len())).map((formatted-dates) => {
              let d = formatted-dates.at(0);
              let i = formatted-dates.at(1);
              let weight = "light"
              if (i == 0) {
                weight = "bold"
              }
              return (
                text(size: 7pt, fill: theme.color, weight: weight, d.title),
                text(size: 7pt, d.date.display("[month repr:short] [day], [year]"))
              )
            }).flatten()
          )
        }
        v(2em)
        grid(columns: 1, gutter: 2em, ..margin.map(side => {
          text(size: 7pt, {
            if ("title" in side) {
              text(fill: theme.color, weight: "bold", side.title)
              [\ ]
            }
            set enum(indent: 0.1em, body-indent: 0.25em)
            set list(indent: 0.1em, body-indent: 0.25em)
            side.content
          })
        }))
      }),
    )
  )

  // =============================== //
  // ========== Abstract =========== //
  // =============================== //
  pubmatter.show-abstract-block(fm)

  // =============================== //
  // =========== Body  ============= //
  // =============================== //
  show par: set par(
    leading: options.line-spacing,
    spacing: options.line-spacing, 
    justify: true,
    first-line-indent: 1em
    )

  show raw.where(block: true): (it) => {
      set text(size: 6pt)
      set align(left)
      block(sticky: true, fill: luma(240), width: 100%, inset: 10pt, radius: 1pt, it)
  }
  show figure.caption: left-caption
  show figure.where(kind: "table"): set figure.caption(position: top)
  show figure.where(kind: "table"): set block(breakable: true)
  set figure(placement: auto)

  // =============================== //
  // ======== Line numbering ======= //
  // =============================== //
  set par.line(
    numbering: "1", 
    // number-clearance: options.number-clearance
    ) if options.line-numbers == true

  // =============================== //
  // ======= Display content ======= //
  // =============================== //
  body

  // =============================== //
  // ======== Bibliography ========= //
  // =============================== //
  if options.bibliography != none {
    set bibliography(
      title: text(10pt, "References"), 
      style: options.bibliography-style
    )
    show bibliography: (it) => {
      set text(7pt)
      set block(spacing: 0.9em)
      it
    }
    bibliography(options.bibliography)
  }
}
#show: lepub.with(
  frontmatter: (
    title: "Belay, a flexible MicroPython interface for experimental hardware control",
    abstract: [
      Behavioural experiments often require specific hardware. Recent years have seen the increased availability of consumer-grade electronics which has led to increased adoption in experimental research. However, interfacing with microcontrollers has remained difficult. Here, we present Belay, a Python package that provides an accessible interface to with microcontrollers running Micropython. We compare it to existing libraries and solutions. We also show that performance remains good in terms of latency. We also show the versatility of using Belay, by showcasing its use from Python scripts, Jupyter Notebooks and within the visual reactive programming language Bonsai.

    ],
          open-access: true,
        github: "https:\/\/github.com/brianpugh/belay",
            keywords: (
            "Software",
            "Hardware",
            "Micropython",
            "Experimental control",
          ),
      authors: (
          (
        name: "Mikkel Roald-Arbøl",
              orcid: "0000-0003-2550-0012",
                    email: "science\@roald-arboel.com",
                    affiliations: (
                    "",
                  ),
            ),
          (
        name: "Brian Pugh",
                        ),
        ),
    affiliations: (
     
      (
        id: "",
        name: "University of Bonn",
      ),
    
    ),
      license: (
      id: "CC-BY-4.0", 
      name: "CC-BY-4.0", 
      url: "https:\/\/creativecommons.org/licenses/by/4.0/"
    )
    ),
  options: (
                          bibliography: (
              ("refs.bib"),
          ),
      parts: (
          ),
      )
)


= Introduction
<introduction>
Behavioural experiments often require specific hardware. Recent years have seen the increased availability of consumer-grade electronics which has led to increased adoption in experimental research. However, interfacing with microcontrollers has remained difficult. Here, we present Belay, a Python package that provides an accessible interface to with microcontrollers running Micropython. We compare it to existing libraries and solutions. We also show that performance remains good in terms of latency. We also show the versatility of using Belay, by showcasing its use from Python scripts, Jupyter Notebooks and within the visual reactive programming language Bonsai @Lopes2015.

LabNet @Schatz2022, Autopilot @Saunders2022, Bpod @zotero-item-7401

= Results
<results>
== Package capabilities
<package-capabilities>
== Integration with Bonsai
<integration-with-bonsai>
== Flexibility
<flexibility>
- MicroPython, CircuitPython

- Python, Jupyter Notebook, Bonsai

- MicroPython: Pyboard, ESP32, ESP8266, Raspberry Pi Pico, BBC micro:bit, STM32 development boards, and a few Arduino boards such as the Nano 33 BLE, Nano RP2040, Giga R1, and Portenta H7

- CircuitPython: #link("https://circuitpython.org/downloads")[list of supported boards]

- Table over different software interfaces:

  - Microcontroller vs.~single-board computer
  - Limited to specific hardware
  - Arduino vs.~MicroPython/CircuitPython
  - Python interface
  - Integration with Bonsai
  - Connectivity (serial/wired, WiFi, Bluetooth, radio)

== Performance
<performance>
- Set/ping test
- Read and set GPIO
- Stress test

== Examples
<examples>
= Discussion
<discussion>
This work showcases the utility of Belay, a Python package for powerful control of Micropython-based microcontrollers. Belay is a general-purpose package, which makes it a powerful tool for experimental science broadly. The fact that it can be used in standard Python scripts, interactively in Jupyter Notebooks or in Bonsai workflows highlights the versatility.

Because of it being open-source and general-purpose, the community around it entails many more users than just those engaged in research, leading to a larger community with greater knowledge sharing.

= Materials & Methods
<materials-methods>
= Data availability
<data-availability>

