package com.yolo

import com.margelo.nitro.yolo.HybridYoloSpec

class HybridYolo: HybridYoloSpec() {    
    override fun sum(num1: Double, num2: Double): Double {
        return num1 + num2
    }
    override fun subtract(num1: Double, num2: Double): Double {
        return num1 - num2
    }
}
