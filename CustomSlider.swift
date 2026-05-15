//
//  CustomSlider.swift
//  EasySnap
//
//  Created by Nyeongwoo Kwon on 5/15/26.
//


import SwiftUI

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private var logMin: Double { log(range.lowerBound) }
    private var logMax: Double { log(range.upperBound) }

    private var percent: Double {
        (log(value) - logMin) / (logMax - logMin)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: CGFloat(percent) * geometry.size.width, height: 4)

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: CGFloat(percent) * geometry.size.width - 10)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let p = max(0, min(1, Double(gesture.location.x / geometry.size.width)))
                                let logValue = logMin + p * (logMax - logMin)
                                let rawValue = exp(logValue)
                                let stepped = (rawValue / step).rounded() * step
                                value = max(range.lowerBound, min(range.upperBound, stepped))
                            }
                    )
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }
}