// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import os

/// The tabs as a vertical bar in a column on the right, drawn to match the one
/// the system puts in the closed Duo's status column.
struct TabRail: View {
    @Binding var selection: AppTab

    /// The closed Duo's column is 84 pt; the open one matches it.
    static let width: CGFloat = 84

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    let isSelected = tab == selection
                    Button {
                        selection = tab
                    } label: {
                        // A label under each icon, as the HIG asks of tab bars;
                        // filled symbols, as the system's tab bar uses.
                        VStack(spacing: 2) {
                            Image(systemName: tab.systemImage)
                                .symbolVariant(.fill)
                                .font(.title3.weight(.semibold))
                            Text(tab.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        .frame(width: 62, height: 56)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(.fill.secondary)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(4)
            .railBackground()
            .padding(.bottom, 8)
        }
        .frame(width: Self.width)
        // Every tab's page is grouped-background, so the column reads as part
        // of the page, as the system's does on the closed Duo.
        .background(Color(.systemGroupedBackground))
    }
}

private extension View {
    @ViewBuilder
    func railBackground() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

// MARK: - Fold signals

/// What iOS says about the device's fold, for choosing where the tabs go.
struct FoldSignals: Equatable {
    /// Whether this is a foldable at all. Stays false on every other iPhone.
    var hasHinge = false
    var isClosed = false
    /// Where the system puts vertical bars, if it does: on the Duo when closed,
    /// and when open in landscape. Nil open in portrait and on other iPhones.
    var verticalEdge: HorizontalEdge?
}

extension View {
    /// Keeps `signals` current. Does nothing before iOS 27.1, which has no Duo.
    func readFoldSignals(_ signals: Binding<FoldSignals>) -> some View {
        modifier(FoldSignalReader(signals: signals))
    }
}

private struct FoldSignalReader: ViewModifier {
    @Binding var signals: FoldSignals

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(HingeReader(signals: $signals))
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct HingeReader: ViewModifier {
    @Binding var signals: FoldSignals
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    private static let log = Logger(subsystem: "com.amendez.crate", category: "layout")

    func body(content: Content) -> some View {
        content
            .onAppear {
                signals.verticalEdge = verticalEdge
                Self.log.notice("vertical edge: \(String(describing: verticalEdge), privacy: .public)")
            }
            .onChange(of: verticalEdge) { edge in
                signals.verticalEdge = edge
                Self.log.notice("vertical edge: \(String(describing: edge), privacy: .public)")
            }
            .onHingeChange { _, new in
                // A nil hinge means this view stopped getting updates (it's
                // moving), not that the device lost its hinge.
                guard let hinge = new.hinge else { return }
                signals.hasHinge = true
                signals.isClosed = hinge.status == .closed
                Self.log.notice("hinge: \(String(describing: hinge.status), privacy: .public)")
            }
    }
}
