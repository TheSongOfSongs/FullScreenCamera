//
//  Filter.swift
//  FullScreenCamera
//
//  Created by Jin on 2020/08/24.
//  Copyright © 2020 com.jinhyang. All rights reserved.
//

import UIKit
import GPUImage

class FilterManager {
    
    static let shared = FilterManager()
    
//    var filterArr: [Filter] = [
//        Filter(filterName: "Original", effectName: ""),
//        Filter(filterName: "Chrome", effectName: "CIPhotoEffectChrome"),
//        Filter(filterName: "Fade", effectName: "CIPhotoEffectFade"),
//        Filter(filterName: "Instant", effectName: "CIPhotoEffectInstant"),
//        Filter(filterName: "Sepia", effectName: "CISepiaTone"),
//        Filter(filterName: "Tonal", effectName: "CIPhotoEffectTonal"),
//        Filter(filterName: "Transfer", effectName: "CIPhotoEffectTransfer")
//    ]
    
//    var currentFilter: String?
    
    var filterArr: [Filter] = [
        Filter(filter: BrightnessAdjustment(), filterName: "Bright", value: 0.5),
        Filter(filter: RGBAdjustment(), filterName: "RGB", value: -0.3),
        Filter(filter: HueAdjustment(), filterName: "Hue", value: 0.3),
        Filter(filter: SepiaToneFilter(), filterName: "Sepia", value: 0.3)
    ]
    
    
    
}

//struct Filter {
//    let filterName: String
//    let effectName: String
//
//    var image: UIImage? {
//        return UIImage(named: "\(filterName)")
//    }
//}


struct Filter {
    let filter: ImageProcessingOperation
    let filterName: String
    let value: Double
    
}
