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
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today) else {
            return ""
        }

        var output = ""
        output += "    " // Left padding for day labels

        let monthLabels = generateMonthLabels(startDate: startDate, weeks: weeks)
        output += monthLabels + "\n"

        let dayLabels = ["Mon", "Wed", "Fri"]
        let dayIndices = [0, 2, 4]

        for (index, label) in zip(dayIndices, dayLabels) {
            output += String(format: "%-3s ", label)

            var currentDate = calendar.date(byAdding: .day, value: index, to: startDate)!

            for _ in 0..<weeks {
                let dateString = dateFormatter.string(from: currentDate)
                let minutes = data[dateString] ?? 0
                let block = getBlockCharacter(for: minutes)
                output += block

                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
            }

            output += "\n"
        }

        output += "\n"
        output += "    ░ None   ▒ Low   ▓ Medium   █ High\n"

        return output
    }

    private func generateMonthLabels(startDate: Date, weeks: Int) -> String {
        let calendar = Calendar.current
        var labels = ""
        var lastMonth = -1
        var currentDate = startDate

        for _ in 0..<weeks {
            let month = calendar.component(.month, from: currentDate)

            if month != lastMonth {
                let monthName = calendar.monthSymbols[month - 1].prefix(3)
                labels += String(monthName)
                lastMonth = month
            } else {
                labels += " "
            }

            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
        }

        return labels
    }

    private func getBlockCharacter(for minutes: Int) -> String {
        switch minutes {
        case 0:
            return "░"
        case 1..<60:
            return "▒"
        case 60..<120:
            return "▓"
        default:
            return "█"
        }
    }
}
