//
//  OverlayView.swift
//  StackedNotifications
//
//  Created by Ulf Akerstedt-Inoue on 2016/12/06.
//  Copyright © 2016 hakkabon. All rights reserved.
//

import UIKit

@available(iOS 9.0, *)
class OverlayViewController: UIViewController {
    
    lazy var overlayView: OverlayView = {
        let overlay = OverlayView()
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.translatesAutoresizingMaskIntoConstraints = true
        overlay.backgroundColor = UIColor.clear
        overlay.isUserInteractionEnabled = true
        return overlay
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.translatesAutoresizingMaskIntoConstraints = true
        self.view.backgroundColor = UIColor.clear
        self.view.isUserInteractionEnabled = true

        // Add overlay subview.
        self.view.addSubview(overlayView)
        overlayView.frame = view.frame
    }
    
    override var shouldAutorotate: Bool { return true }
}
