//
//  SeparatorLine.swift
//  StackedNotifications
//
//  Created by Ulf Akerstedt-Inoue on 2018/04/10.
//  Copyright © 2018 hakkabon. All rights reserved.
//

import UIKit

class SeparatorLine: UIView {
    
    var thickness: CGFloat = 1.0
    var color: UIColor = UIColor.white {
        didSet {
            lineCGColor = color.cgColor
        }
    }
    
    internal var lineCGColor: CGColor?
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw a line from the left to the right at the midpoint of the view's rect height.
        let y0 = self.bounds.midY
        context.setLineWidth(thickness)
        if let lineCGColor = self.lineCGColor {
            context.setStrokeColor(lineCGColor)
        } else {
            context.setStrokeColor(UIColor.black.cgColor)
        }
        context.move(to: CGPoint(x: 0.0, y: y0))
        context.addLine(to: CGPoint(x: self.bounds.size.width, y: y0))
        context.strokePath()
    }
}
