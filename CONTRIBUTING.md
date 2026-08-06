# Contributing to Janus

Thanks for helping improve Janus. This document collects the conventions that a
pull request is checked against.

## Source file encoding

**Every file under `Source/` is pure ASCII and carries no BOM.**

That is the whole rule. It is enforced by
`Test.Janus.Source.Encoding` in `Janus.Tests.Units`, which the CI job runs, so a
pull request that breaks it fails before review.

### Writing text a user will read

A message, caption or exception text often needs an accent. Write the character
as a Delphi `#$XXXX` escape, concatenated with the ASCII parts of the literal:

```pascal
// wrong - depends on how your editor saved the file
raise Exception.Create('Não foi passado o parâmetro com os dados do insert!');

// right - the file stays ASCII, the compiled string still carries the accents
raise Exception.Create('N'#$00E3'o foi passado o par'#$00E2'metro com os dados do insert!');
```

Common characters:

| character | escape | | character | escape |
| :--- | :--- | :--- | :--- | :--- |
| á | `#$00E1` | | ó | `#$00F3` |
| â | `#$00E2` | | ô | `#$00F4` |
| ã | `#$00E3` | | õ | `#$00F5` |
| ç | `#$00E7` | | ú | `#$00FA` |
| é | `#$00E9` | | — (em dash) | `#$2014` |
| í | `#$00ED` | | → (arrow) | `#$2192` |

`Test.Janus.Driver.Register.GetDriver_MessageCarriesItsAccentsAsCodepoints`
asserts on the ordinals a shipped message actually carries, so the escapes are
pinned to reach the binary, not merely to compile.

### Writing comments

Comments are not read by a user, so they carry no escapes: **spell them in
ASCII.** Write `parametro`, not `parâmetro`; write `-`, not `—`.

### Why ASCII, and not "cp1252 is fine, UTF-8 is not"

Historically these files were cp1252 without a BOM, which is what `dcc32` assumes
when it reads a `.pas` with no BOM. The obvious rule would be "keep cp1252, reject
UTF-8". It cannot be enforced, because **the two are not distinguishable by
looking at the bytes**: the cp1252 text `Ã©` and the UTF-8 encoding of `é` are the
same two bytes, `C3 A9`. Any checker phrased that way has to guess.

That is not one lucky counter-example. A two-byte UTF-8 sequence is a lead byte
in `C2`–`DF` followed by a continuation byte in `80`–`BF`; cp1252 leaves only
five of those bytes undefined (`81`, `8D`, `8F`, `90`, `9D`), all of them in the
continuation range. So **1770 of the 1920 two-byte UTF-8 sequences are legal
cp1252 text as well** — 30 lead bytes × 59 continuation bytes.

ASCII-only is decidable — a byte is either below `$80` or it is not — and the
`#$XXXX` escape gives back everything the stricter rule costs, with a bonus: an
escaped literal is immune to being re-saved in the wrong encoding by an editor,
a merge tool, or a copy-paste. That is exactly how the damage below happened.

When the rule was introduced, all of `Source/` held **three** non-ASCII bytes
that were not already corrupt, in one file. The cost of the stricter rule was
those three bytes. Today it costs **35 escaped characters on 23 lines, in 13 of
134 units** — the Portuguese in this repository is overwhelmingly in comments,
and comments are simply written in ASCII.

### If Janus ever grows a real body of user-facing Portuguese

The escape stops being comfortable somewhere around a translation table. If an
i18n or string-resource layer is ever added, **the answer is not to loosen this
guard** — it cannot be loosened into anything enforceable, for the reason above.

The answer is to move that text into **resource files with a declared encoding
and a BOM** (`.resx`, `.po`, `.json`, a `.rc` string table — anything whose
encoding is stated rather than assumed), and exempt that path from the guard by
adding it to the excluded set alongside `Source/External/`. A BOM makes the
encoding a fact about the file instead of a guess about the compiler, which is
the property `Source/` does not have and cannot get without one.

### The baseline, and why it is empty

`Source/` used to carry U+FFFD characters inside comments — accents destroyed by
a past re-encode, where the original letter is gone. They were tolerated through
a shrink-only baseline in `Test.Janus.Source.Encoding`. **That baseline is now
empty**: every file under `Source/` is held to plain ASCII with no exception, and
`BaselineIsAtZeroAndTheTreeAgrees` fails both if a row is added back and if a
U+FFFD reappears anywhere.

Repairing the last of them needed a rule worth writing down, because the next
person to meet a U+FFFD will need it:

> A U+FFFD proves a non-ASCII byte stood there — so the unaccented spelling is
> ruled out by construction — but it says only **that** an accent existed, never
> **which** one.

So it is a per-occurrence judgement, never a bulk substitution. Recover the word
from the surrounding Portuguese, then write **that word** in ASCII: `par?metro`
was `parâmetro`, so it becomes `parametro`.

The trap is the case where the ASCII spelling is a *different Portuguese word*.
Flattening `é` (is) to `e` yields `e` (and); `está` (is at) yields `esta` (this);
and the same holds for `tem`/`têm`, `pode`/`pôde`, `por`/`pôr`. **Every one of
those folds into a sentence that still reads correctly**, which is exactly why a
mechanical fold corrupts silently. In those cases **reword the sentence** — drop
the copula, use the reflexive, or switch to the active voice — rather than
flatten the word.

## Line endings

Files in this repository use **CRLF**. Do not let an editor or a script rewrite
them; a diff that shows every line changed will be sent back.

## Tests

The gate is four DUnitX projects under `Test/Delphi`:

| project | what it covers |
| :--- | :--- |
| `Janus.Tests.Units` | the shipped default configuration (`DRIVERRESTFUL` off) |
| `Janus.Tests.LiveBindings` | the LiveBindings binder |
| `Janus.Tests.RESTHorse` | the Horse REST leg |
| `Janus.Tests.RESTfulDriver` | the opt-in configuration (`DRIVERRESTFUL` on) |

Build and run them before opening a pull request:

```
call "C:\Program Files (x86)\Embarcadero\Studio\<version>\bin\rsvars.bat"
cd Test\Delphi
msbuild Janus.Tests.Units.dproj /t:Build
Janus.Tests.Units.exe
```

`Janus.Tests.RESTOracle` needs a live Oracle instance and is not part of the
gate; its tests error out without one.

## Pull requests

* One concern per pull request.
* Say what you measured, and how. A claim about behaviour that was not observed
  is the most expensive kind of mistake to undo, because it outlives the code.
* Do not commit build output: `.dcu`, `.exe`, `.identcache`, or the generated
  `Test\Delphi\Janus.Tests.*.res` files.
