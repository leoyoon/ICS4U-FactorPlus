//
//  ScatterChartRenderer.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics
import UIKit

open class ScatterChartRenderer: LineScatterCandleRadarChartRenderer
{
    open weak var dataProvider: ScatterChartDataProvider?
    
    public init(dataProvider: ScatterChartDataProvider?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard let scatterData = dataProvider?.scatterData else { return }
        
        for (i in 0 ..< scatterData.dataSetCount)
        {
            let set = scatterData.getDataSetByIndex(i)
            
            if (set !== nil && set!.isVisible)
            {
                drawDataSet(context: context, dataSet: set as! ScatterChartDataSet)
            }
        }
    }
    
    fileprivate var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    internal func drawDataSet(context: CGContext, dataSet: ScatterChartDataSet)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(dataSet.axisDependency)
        
        let phaseY = _animator.phaseY
        
        var entries = dataSet.yVals
        
        let shapeSize = dataSet.scatterShapeSize
        let shapeHalf = shapeSize / 2.0
        
        var point = CGPoint()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let shape = dataSet.scatterShape
        
        context.saveGState()
        
        for (var j = 0, count = Int(min(ceil(CGFloat(entries.count) * _animator.phaseX), CGFloat(entries.count))); j < count; j += 1)
        {
            let e = entries[j]
            point.x = CGFloat(e.xIndex)
            point.y = CGFloat(e.value) * phaseY
            point = point.applying(valueToPixelMatrix);            
            
            if (!viewPortHandler.isInBoundsRight(point.x))
            {
                break
            }
            
            if (!viewPortHandler.isInBoundsLeft(point.x) || !viewPortHandler.isInBoundsY(point.y))
            {
                continue
            }
            
            if (shape == .square)
            {
                context.setFillColor(dataSet.colorAt(j).cgColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                context.fill(rect)
            }
            else if (shape == .circle)
            {
                context.setFillColor(dataSet.colorAt(j).cgColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                context.fillEllipse(in: rect)
            }
            else if (shape == .cross)
            {
                context.setStrokeColor(dataSet.colorAt(j).cgColor)
                _lineSegments[0].x = point.x - shapeHalf
                _lineSegments[0].y = point.y
                _lineSegments[1].x = point.x + shapeHalf
                _lineSegments[1].y = point.y
                CGContextStrokeLineSegments(context, _lineSegments, 2)
                
                _lineSegments[0].x = point.x
                _lineSegments[0].y = point.y - shapeHalf
                _lineSegments[1].x = point.x
                _lineSegments[1].y = point.y + shapeHalf
                CGContextStrokeLineSegments(context, _lineSegments, 2)
            }
            else if (shape == .triangle)
            {
                context.setFillColor(dataSet.colorAt(j).cgColor)
                
                // create a triangle path
                context.beginPath()
                context.move(to: CGPoint(x: point.x, y: point.y - shapeHalf))
                context.addLine(to: CGPoint(x: point.x + shapeHalf, y: point.y + shapeHalf))
                context.addLine(to: CGPoint(x: point.x - shapeHalf, y: point.y + shapeHalf))
                context.closePath()
                
                context.fillPath()
            }
            else if (shape == .custom)
            {
                context.setFillColor(dataSet.colorAt(j).cgColor)
                
                let customShape = dataSet.customScatterShape
                
                if customShape == nil
                {
                    return
                }
                
                // transform the provided custom path
                context.saveGState()
                context.translateBy(x: point.x, y: point.y)
                
                context.beginPath()
                context.addPath(customShape!)
                context.fillPath()
                
                context.restoreGState()
            }
        }
        
        context.restoreGState()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard let dataProvider = dataProvider, let scatterData = dataProvider.scatterData else { return }
        
        // if values are drawn
        if (scatterData.yValCount < Int(ceil(CGFloat(dataProvider.maxVisibleValueCount) * viewPortHandler.scaleX)))
        {
            var dataSets = scatterData.dataSets as! [ScatterChartDataSet]
            
            for (i in 0 ..< scatterData.dataSetCount)
            {
                let dataSet = dataSets[i]
                
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let valueFont = dataSet.valueFont
                let valueTextColor = dataSet.valueTextColor
                
                let formatter = dataSet.valueFormatter
                
                var entries = dataSet.yVals
                
                var positions = dataProvider.getTransformer(dataSet.axisDependency).generateTransformedValuesScatter(entries, phaseY: _animator.phaseY)
                
                let shapeSize = dataSet.scatterShapeSize
                let lineHeight = valueFont.lineHeight
                
                for (var j = 0, count = Int(ceil(CGFloat(positions.count) * _animator.phaseX)); j < count; j += 1)
                {
                    if (!viewPortHandler.isInBoundsRight(positions[j].x))
                    {
                        break
                    }
                    
                    // make sure the lines don't do shitty things outside bounds
                    if ((!viewPortHandler.isInBoundsLeft(positions[j].x)
                        || !viewPortHandler.isInBoundsY(positions[j].y)))
                    {
                        continue
                    }
                    
                    let val = entries[j].value
                    
                    let text = formatter!.string(from: val)
                    
                    ChartUtils.drawText(context: context, text: text!, point: CGPoint(x: positions[j].x, y: positions[j].y - shapeSize - lineHeight), align: .center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        
    }
    
    fileprivate var _highlightPointBuffer = CGPoint()
    
    open override func drawHighlighted(context: CGContext, indices: [ChartHighlight])
    {
        guard let dataProvider = dataProvider, let scatterData = dataProvider.scatterData else { return }
        
        let chartXMax = dataProvider.chartXMax
        
        context.saveGState()
        
        for (i in 0 ..< indices.count)
        {
            guard let set = scatterData.getDataSetByIndex(indices[i].dataSetIndex) as? ScatterChartDataSet else { continue }
            
            if !set.isHighlightEnabled
            {
                continue
            }
            
            context.setStrokeColor(set.highlightColor.cgColor)
            context.setLineWidth(set.highlightLineWidth)
            if (set.highlightLineDashLengths != nil)
            {
                CGContextSetLineDash(context, set.highlightLineDashPhase, set.highlightLineDashLengths!, set.highlightLineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            let xIndex = indices[i].xIndex; // get the x-position
            
            if (CGFloat(xIndex) > CGFloat(chartXMax) * _animator.phaseX)
            {
                continue
            }
            
            let yVal = set.yValForXIndex(xIndex)
            if (yVal.isNaN)
            {
                continue
            }
            
            let y = CGFloat(yVal) * _animator.phaseY; // get the y-position
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            let trans = dataProvider.getTransformer(set.axisDependency)
            
            trans.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        context.restoreGState()
    }
}
