import Foundation

struct HeatmapRenderer {
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    func render(data: [String: Int], weeks: Int = 52) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Start from January 1st of the current year
        let currentYear = calendar.component(.year, from: today)
        var components = DateComponents()
        components.year = currentYear
        components.month = 1
        components.day = 1
        guard let yearStart = calendar.date(from: components) else {
            return "Unable to generate heatmap"
        }

        // Find the first Monday on or after Jan 1
        let weekday = calendar.component(.weekday, from: yearStart)
        // If Jan 1 is not Monday (weekday 2), find the next Monday
        let daysUntilMonday = weekday == 2 ? 0 : (9 - weekday) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: daysUntilMonday, to: yearStart) else {
            return "Unable to generate heatmap"
        }

        var output = ""
        output += "      " // Left padding for day labels

        let monthLabels = generateMonthLabels(startDate: weekStart, weeks: weeks)
        output += monthLabels + "\n"
        output += "\n"

        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let dayIndices = [0, 1, 2, 3, 4, 5, 6]

        for (index, label) in zip(dayIndices, dayLabels) {
            // Add day label every other day for visual spacing
            if index % 2 == 0 {
                output += label.padding(toLength: 6, withPad: " ", startingAt: 0)
            } else {
                output += "      "
            }

            guard var currentDate = calendar.date(byAdding: .day, value: index, to: weekStart) else {
                continue
            }

            // Show exactly 52 weeks
            for _ in 0..<weeks {
                let dateString = dateFormatter.string(from: currentDate)

                // Check if date is in the future
                if currentDate > today {
                    output += "·"
                } else {
                    let minutes = data[dateString] ?? 0
                    let block = getBlockCharacter(for: minutes)
                    output += block
                }

                guard let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else {
                    break
                }
                currentDate = nextDate
            }

            output += "\n"
        }

        output += "\n"
        output += "      Less · ░ ▒ ▓ █ · More\n"

        return output
    }

    private func generateMonthLabels(startDate: Date, weeks: Int) -> String {
        let calendar = Calendar.current
        var labels: [Character] = Array(repeating: " ", count: weeks)
        var currentDate = startDate

        for i in 0..<weeks {
            let month = calendar.component(.month, from: currentDate)
            let year = calendar.component(.year, from: currentDate)

            // Check if this is a new month (or start of data)
            let isNewMonth: Bool
            if i == 0 {
                isNewMonth = true
            } else if let prevDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) {
                let prevMonth = calendar.component(.month, from: prevDate)
                let prevYear = calendar.component(.year, from: prevDate)
                isNewMonth = (month != prevMonth || year != prevYear)
            } else {
                isNewMonth = false
            }

            // Place label if it's a new month and won't overwrite existing label
            if isNewMonth && month >= 1 && month <= calendar.monthSymbols.count {
                let monthName = String(calendar.monthSymbols[month - 1].prefix(3))
                let charsToPlace = min(3, weeks - i)

                // Check if placing this label would overwrite or be adjacent to a previous label
                var canPlace = true

                // Check if position immediately before has a letter (no space buffer)
                if i > 0 && labels[i - 1] != " " {
                    canPlace = false
                }

                // Check if the positions we need are available
                if canPlace {
                    for j in 0..<charsToPlace {
                        if i + j < weeks && labels[i + j] != " " {
                            canPlace = false
                            break
                        }
                    }
                }

                if canPlace {
                    for j in 0..<charsToPlace {
                        labels[i + j] = monthName[monthName.index(monthName.startIndex, offsetBy: j)]
                    }
                }
            }

            guard let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return String(labels)
    }

    private func getBlockCharacter(for minutes: Int) -> String {
        switch minutes {
        case 0:
            return "·"
        case 1..<60:
            return "░"
        case 60..<120:
            return "▒"
        case 120..<180:
            return "▓"
        default:
            return "█"
        }
    }
}
