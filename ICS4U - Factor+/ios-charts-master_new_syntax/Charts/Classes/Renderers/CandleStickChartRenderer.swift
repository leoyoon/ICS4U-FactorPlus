//
//  CandleStickChartRenderer.swift
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

open class CandleStickChartRenderer: LineScatterCandleRadarChartRenderer
{
    open weak var dataProvider: CandleChartDataProvider?
    
    public init(dataProvider: CandleChartDataProvider?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard let dataProvider = dataProvider, let candleData = dataProvider.candleData else { return }

        for set in candleData.dataSets as! [CandleChartDataSet]
        {
            if set.isVisible && set.entryCount > 0
            {
                drawDataSet(context: context, dataSet: set)
            }
        }
    }
    
    fileprivate var _shadowPoints = [CGPoint](repeating: CGPoint(), count: 2)
    fileprivate var _bodyRect = CGRect()
    fileprivate var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    internal func drawDataSet(context: CGContext, dataSet: CandleChartDataSet)
    {
        guard let trans = dataProvider?.getTransformer(dataSet.axisDependency) else { return }
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        let bodySpace = dataSet.bodySpace
        
        var entries = dataSet.yVals as! [CandleChartDataEntry]
        
        let minx = max(_minX, 0)
        let maxx = min(_maxX + 1, entries.count)
        
        context.saveGState()
        
        context.setLineWidth(dataSet.shadowWidth)
        
        for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx))); j < count; j += 1)
        {
            // get the entry
            let e = entries[j]
            
            if (e.xIndex < _minX || e.xIndex > _maxX)
            {
                continue
            }
            
            // calculate the shadow
            
            _shadowPoints[0].x = CGFloat(e.xIndex)
            _shadowPoints[0].y = CGFloat(e.high) * phaseY
            _shadowPoints[1].x = CGFloat(e.xIndex)
            _shadowPoints[1].y = CGFloat(e.low) * phaseY
            
            trans.pointValuesToPixel(&_shadowPoints)
            
            // draw the shadow
            
            var shadowColor: UIColor! = nil
            if (dataSet.shadowColorSameAsCandle)
            {
                if (e.open > e.close)
                {
                    shadowColor = dataSet.decreasingColor ?? dataSet.colorAt(j)
                }
                else if (e.open < e.close)
                {
                    shadowColor = dataSet.increasingColor ?? dataSet.colorAt(j)
                }
            }
            
            if (shadowColor === nil)
            {
                shadowColor = dataSet.shadowColor ?? dataSet.colorAt(j);
            }
            
            context.setStrokeColor(shadowColor.cgColor)
            CGContextStrokeLineSegments(context, _shadowPoints, 2)
            
            // calculate the body
            
            _bodyRect.origin.x = CGFloat(e.xIndex) - 0.5 + bodySpace
            _bodyRect.origin.y = CGFloat(e.close) * phaseY
            _bodyRect.size.width = (CGFloat(e.xIndex) + 0.5 - bodySpace) - _bodyRect.origin.x
            _bodyRect.size.height = (CGFloat(e.open) * phaseY) - _bodyRect.origin.y
            
            trans.rectValueToPixel(&_bodyRect)
            
            // draw body differently for increasing and decreasing entry
            
            if (e.open > e.close)
            {
                let color = dataSet.decreasingColor ?? dataSet.colorAt(j)
                
                if (dataSet.isDecreasingFilled)
                {
                    context.setFillColor(color.cgColor)
                    context.fill(_bodyRect)
                }
                else
                {
                    context.setStrokeColor(color.cgColor)
                    context.stroke(_bodyRect)
                }
            }
            else if (e.open < e.close)
            {
                let color = dataSet.increasingColor ?? dataSet.colorAt(j)
                
                if (dataSet.isIncreasingFilled)
                {
                    context.setFillColor(color.cgColor)
                    context.fill(_bodyRect)
                }
                else
                {
                    context.setStrokeColor(color.cgColor)
                    context.stroke(_bodyRect)
                }
            }
            else
            {
                context.setStrokeColor(shadowColor.cgColor)
                context.stroke(_bodyRect)
            }
        }
        
        context.restoreGState()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard let dataProvider = dataProvider, let candleData = dataProvider.candleData else { return }
        
        // if values are drawn
        if (candleData.yValCount < Int(ceil(CGFloat(dataProvider.maxVisibleValueCount) * viewPortHandler.scaleX)))
        {
            var dataSets = candleData.dataSets
            
            for (i in 0 ..< dataSets.count)
            {
                let dataSet = dataSets[i]
                
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let valueFont = dataSet.valueFont
                let valueTextColor = dataSet.valueTextColor
                
                let formatter = dataSet.valueFormatter
                
                let trans = dataProvider.getTransformer(dataSet.axisDependency)
                
                var entries = dataSet.yVals as! [CandleChartDataEntry]
                
                let minx = max(_minX, 0)
                let maxx = min(_maxX + 1, entries.count)
                
                var positions = trans.generateTransformedValuesCandle(entries, phaseY: _animator.phaseY)
                
                let lineHeight = valueFont.lineHeight
                let yOffset: CGFloat = lineHeight + 5.0
                
                for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * _animator.phaseX + CGFloat(minx))); j < count; j += 1)
                {
                    let x = positions[j].x
                    let y = positions[j].y
                    
                    if (!viewPortHandler.isInBoundsRight(x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(x) || !viewPortHandler.isInBoundsY(y))
                    {
                        continue
                    }
                    
                    let val = entries[j].high
                    
                    ChartUtils.drawText(context: context, text: formatter!.string(from: val)!, point: CGPoint(x: x, y: y - yOffset), align: .center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
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
        guard let dataProvider = dataProvider, let candleData = dataProvider.candleData else { return }
        
        context.saveGState()
        
        for (i in 0 ..< indices.count)
        {
            let xIndex = indices[i].xIndex; // get the x-position
            
            let set = candleData.getDataSetByIndex(indices[i].dataSetIndex) as! CandleChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
            let e = set.entryForXIndex(xIndex) as! CandleChartDataEntry!
            
            if (e === nil || e.xIndex != xIndex)
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(set.axisDependency)
            
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
            
            let low = CGFloat(e.low) * _animator.phaseY
            let high = CGFloat(e.high) * _animator.phaseY
            let y = (low + high) / 2.0
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            trans.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        context.restoreGState()
    }
}
