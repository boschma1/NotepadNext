import Foundation

/// Generates Lorem Ipsum filler text, Word-style:
///   `=rand(p)`    → p paragraphs of 3 sentences each
///   `=rand(p, s)` → p paragraphs of s sentences each
enum LoremIpsum {

    /// A pool of classic Lorem Ipsum sentences. Iterated cyclically so the
    /// output is deterministic and well-distributed.
    private static let sentences: [String] = [
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
        "Curabitur pretium tincidunt lacus, nulla gravida orci a odio.",
        "Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris.",
        "Integer in mauris eu nibh euismod gravida.",
        "Duis ac tellus et risus vulputate vehicula.",
        "Donec lobortis risus a elit.",
        "Etiam tempor.",
        "Ut ullamcorper, ligula eu tempor congue, eros est euismod turpis, id tincidunt sapien risus a quam.",
    ]

    static func generate(paragraphs: Int, sentences sentencesPerParagraph: Int) -> String {
        guard paragraphs > 0, sentencesPerParagraph > 0 else { return "" }

        var idx = 0
        var result: [String] = []
        result.reserveCapacity(paragraphs)

        for _ in 0..<paragraphs {
            var paragraph: [String] = []
            paragraph.reserveCapacity(sentencesPerParagraph)
            for _ in 0..<sentencesPerParagraph {
                paragraph.append(sentences[idx % sentences.count])
                idx += 1
            }
            result.append(paragraph.joined(separator: " "))
        }

        return result.joined(separator: "\n\n")
    }
}
