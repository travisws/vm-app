//
//  VMWidgetBundle.swift
//  VMWidget
//
//  Created by deathpoolops on 12/8/24.
//

import WidgetKit
import SwiftUI

@main
struct VMWidgetBundle: WidgetBundle {
    var body: some Widget {
        VMWidget()
        VMWidgetControl()
        VMWidgetLiveActivity()
    }
}
