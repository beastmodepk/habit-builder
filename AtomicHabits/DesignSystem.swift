import SwiftUI
import UIKit

/// Atomic Habits design system — "Apple luxury":
/// Large Title hierarchy, near-white / true-black grounds, graphite text,
/// deep green for Build, warm amber for Quit, champagne reserved for
/// streak / identity highlights. Big rounded cards, soft shadows, hairline
/// separators, generous whitespace. SF Symbols only — no emoji UI icons.
enum AHColor {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let background = dynamic(
        light: UIColor(red: 0.973, green: 0.973, blue: 0.961, alpha: 1),   // near-white
        dark: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)            // true black
    )
    static let surface = dynamic(
        light: UIColor(white: 1.0, alpha: 1),
        dark: UIColor(red: 0.063, green: 0.063, blue: 0.071, alpha: 1)
    )
    static let surfaceRaised = dynamic(
        light: UIColor(white: 1.0, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    )
    static let graphite = dynamic(
        light: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1)
    )
    static let graphiteSecondary = dynamic(
        light: UIColor(red: 0.42, green: 0.42, blue: 0.45, alpha: 1),
        dark: UIColor(red: 0.62, green: 0.62, blue: 0.66, alpha: 1)
    )
    static let hairline = dynamic(
        light: UIColor.black.withAlphaComponent(0.07),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    /// Build — deep green.
    static let build = dynamic(
        light: UIColor(red: 0.055, green: 0.36, blue: 0.20, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.72, blue: 0.42, alpha: 1)
    )
    /// Quit — warm amber.
    static let quit = dynamic(
        light: UIColor(red: 0.66, green: 0.42, blue: 0.05, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.66, blue: 0.25, alpha: 1)
    )
    /// Streaks & identity highlights only — subtle champagne.
    static let champagne = dynamic(
        light: UIColor(red: 0.66, green: 0.53, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.79, green: 0.66, blue: 0.42, alpha: 1)
    )

    static func accent(for kind: HabitKind) -> Color {
        kind == .build ? build : quit
    }
}

enum AHFont {
    static let heroNumber = Font.system(size: 44, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .default)
    static let metric = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
}

/// Large rounded card: 22pt radius, soft shadow, hairline edge.
struct AHCard: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AHColor.surface)
                    .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AHColor.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func ahCard(padding: CGFloat = 18) -> some View {
        modifier(AHCard(padding: padding))
    }

    /// Translucent material header band.
    func ahMaterialHeader() -> some View {
        self
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
    }
}

/// Apple Fitness-style activity ring: gradient stroke, rounded cap,
/// animated progress, centred label stack.
struct ActivityRingView: View {
    var progress: Double            // 0...1
    var color: Color = AHColor.build
    var size: CGFloat = 148
    var lineWidth: CGFloat = 14
    var title: String = ""
    var subtitle: String = ""

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(progress, 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.75), color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.7), value: progress)
            VStack(spacing: 2) {
                Text(title)
                    .font(AHFont.metric)
                    .foregroundStyle(AHColor.graphite)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AHFont.caption)
                        .foregroundStyle(AHColor.graphiteSecondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// Minimal chain / heatmap cell strip — soft squares, accent when done,
/// champagne when the day was a 2-minute vote.
struct ChainStripView: View {
    let habit: Habit
    var days: Int = 14
    var cell: CGFloat = 13

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(Array((0..<days).reversed()), id: \.self) { offset in
                let day = DayHelper.string(daysAgo: offset)
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(fill(for: day))
                    .frame(width: cell, height: cell)
            }
        }
        .accessibilityLabel("Last \(days) days")
    }

    private func fill(for day: String) -> Color {
        guard habit.isChecked(on: day) else { return AHColor.hairline }
        if habit.checkinKind(on: day) == .twoMinute { return AHColor.champagne }
        return AHColor.accent(for: habit.kind)
    }
}

/// Month chain grid (elegant minimal heatmap): 7 columns, one month of days.
struct MonthChainView: View {
    let habit: Habit
    var days: Int = 35

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array((0..<days).reversed()), id: \.self) { offset in
                let day = DayHelper.string(daysAgo: offset)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill(for: day))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityLabel("Last \(days) days chain")
    }

    private func fill(for day: String) -> Color {
        guard habit.isChecked(on: day) else { return AHColor.hairline.opacity(0.6) }
        if habit.checkinKind(on: day) == .twoMinute { return AHColor.champagne }
        return AHColor.accent(for: habit.kind)
    }
}

/// Small champagne streak pill with a flame SF Symbol.
struct StreakPill: View {
    let streak: Int
    var label: String = "day streak"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(AHColor.champagne)
            Text("\(streak) \(label)")
                .font(AHFont.caption)
                .foregroundStyle(AHColor.graphite)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(AHColor.champagne.opacity(0.13)))
    }
}

/// Section heading in the luxury style: small caps graphite + optional icon.
struct AHSectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = AHColor.graphiteSecondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(color)
            }
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(color)
        }
    }
}
