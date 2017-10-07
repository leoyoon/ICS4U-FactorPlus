//
//  ChartXAxisRendererHorizontalBarChart.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 3/3/15.
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

open class ChartXAxisRendererHorizontalBarChart: ChartXAxisRendererBarChart
{
    public override init(viewPortHandler: ChartViewPortHandler, xAxis: ChartXAxis, transformer: ChartTransformer!, chart: BarChartView)
    {
        super.init(viewPortHandler: viewPortHandler, xAxis: xAxis, transformer: transformer, chart: chart)
    }
    
    open override func computeAxis(xValAverageLength: Double, xValues: [String?])
    {
        _xAxis.values = xValues
       
        let longest = _xAxis.getLongestLabel() as NSString
        
        let labelSize = longest.size(attributes: [NSFontAttributeName: _xAxis.labelFont])
        
        let labelWidth = floor(labelSize.width + _xAxis.xOffset * 3.5)
        let labelHeight = labelSize.height
        
        let labelRotatedSize = ChartUtils.sizeOfRotatedRectangle(rectangleWidth: labelSize.width, rectangleHeight:  labelHeight, degrees: _xAxis.labelRotationAngle)
        
        _xAxis.labelWidth = labelWidth
        _xAxis.labelHeight = labelHeight
        _xAxis.labelRotatedWidth = round(labelRotatedSize.width + _xAxis.xOffset * 3.5)
        _xAxis.labelRotatedHeight = round(labelRotatedSize.height)
    }

    open override func renderAxisLabels(context: CGContext)
    {
        if (!_xAxis.isEnabled || !_xAxis.isDrawLabelsEnabled || _chart.data === nil)
        {
            return
        }
        
        let xoffset = _xAxis.xOffset
        
        if (_xAxis.labelPosition == .top)
        {
            drawLabels(context: context, pos: viewPortHandler.contentRight + xoffset, anchor: CGPoint(x: 0.0, y: 0.5))
        }
        else if (_xAxis.labelPosition == .topInside)
        {
            drawLabels(context: context, pos: viewPortHandler.contentRight - xoffset, anchor: CGPoint(x: 1.0, y: 0.5))
        }
        else if (_xAxis.labelPosition == .bottom)
        {
            drawLabels(context: context, pos: viewPortHandler.contentLeft - xoffset, anchor: CGPoint(x: 1.0, y: 0.5))
        }
        else if (_xAxis.labelPosition == .bottomInside)
        {
            drawLabels(context: context, pos: viewPortHandler.contentLeft + xoffset, anchor: CGPoint(x: 0.0, y: 0.5))
        }
        else
        { // BOTH SIDED
            drawLabels(context: context, pos: viewPortHandler.contentRight + xoffset, anchor: CGPoint(x: 0.0, y: 0.5))
            drawLabels(context: context, pos: viewPortHandler.contentLeft - xoffset, anchor: CGPoint(x: 1.0, y: 0.5))
        }
    }

    /// draws the x-labels on the specified y-position
    internal override func drawLabels(context: CGContext, pos: CGFloat, anchor: CGPoint)
    {
        let labelFont = _xAxis.labelFont
        let labelTextColor = _xAxis.labelTextColor
        let labelRotationAngleRadians = _xAxis.labelRotationAngle * ChartUtils.Math.FDEG2RAD
        
        // pre allocate to save performance (dont allocate in loop)
        var position = CGPoint(x: 0.0, y: 0.0)
        
        let bd = _chart.data as! BarChartData
        let step = bd.dataSetCount
        
        for (var i = _minX, maxX = min(_maxX + 1, _xAxis.values.count); i < maxX; i += _xAxis.axisLabelModulus)
        {
            let label = _xAxis.values[i]
            
            if (label == nil)
            {
                continue
            }
            
            position.x = 0.0
            position.y = CGFloat(i * step) + CGFloat(i) * bd.groupSpace + bd.groupSpace / 2.0
            
            // consider groups (center label for each group)
            if (step > 1)
            {
                position.y += (CGFloat(step) - 1.0) / 2.0
            }
            
            transformer.pointValueToPixel(&position)
            
            if (viewPortHandler.isInBoundsY(position.y))
            {
                drawLabel(context: context, label: label!, xIndex: i, x: pos, y: position.y, attributes: [NSFontAttributeName: labelFont, NSForegroundColorAttributeName: labelTextColor], anchor: anchor, angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    internal func drawLabel(context: CGContext, label: String, xIndex: Int, x: CGFloat, y: CGFloat, attributes: [String: NSObject], anchor: CGPoint, angleRadians: CGFloat)
    {
        let formattedLabel = _xAxis.valueFormatter?.stringForXValue(xIndex, original: label, viewPortHandler: viewPortHandler) ?? label
        ChartUtils.drawText(context: context, text: formattedLabel, point: CGPoint(x: x, y: y), attributes: attributes, anchor: anchor, angleRadians: angleRadians)
    }
    
    fileprivate var _gridLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open override func renderGridLines(context: CGContext)
    {
        if (!_xAxis.isEnabled || !_xAxis.isDrawGridLinesEnabled || _chart.data === nil)
        {
            return
        }
        
        context.saveGState()
        
        context.setStrokeColor(_xAxis.gridColor.cgColor)
        context.setLineWidth(_xAxis.gridLineWidth)
        if (_xAxis.gridLineDashLengths != nil)
        {
            CGContextSetLineDash(context, _xAxis.gridLineDashPhase, _xAxis.gridLineDashLengths, _xAxis.gridLineDashLengths.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        let bd = _chart.data as! BarChartData
        
        // take into consideration that multiple DataSets increase _deltaX
        let step = bd.dataSetCount
        
        for (var i = _minX, maxX = min(_maxX + 1, _xAxis.values.count); i < maxX; i += _xAxis.axisLabelModulus)
        {
            position.x = 0.0
            position.y = CGFloat(i * step) + CGFloat(i) * bd.groupSpace - 0.5
            
            transformer.pointValueToPixel(&position)
            
            if (viewPortHandler.isInBoundsY(position.y))
            {
                _gridLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
                _gridLineSegmentsBuffer[0].y = position.y
                _gridLineSegmentsBuffer[1].x = viewPortHandler.contentRight
                _gridLineSegmentsBuffer[1].y = position.y
                CGContextStrokeLineSegments(context, _gridLineSegmentsBuffer, 2)
            }
        }
        
        context.restoreGState()
    }
    
    fileprivate var _axisLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open override func renderAxisLine(context: CGContext)
    {
        if (!_xAxis.isEnabled || !_xAxis.isDrawAxisLineEnabled)
        {
            return
        }
        
        context.saveGState()
        
        context.setStrokeColor(_xAxis.axisLineColor.cgColor)
        context.setLineWidth(_xAxis.axisLineWidth)
        if (_xAxis.axisLineDashLengths != nil)
        {
            CGContextSetLineDash(context, _xAxis.axisLineDashPhase, _xAxis.axisLineDashLengths, _xAxis.axisLineDashLengths.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        if (_xAxis.labelPosition == .top
            || _xAxis.labelPosition == .topInside
            || _xAxis.labelPosition == .bothSided)
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }
        
        if (_xAxis.labelPosition == .bottom
            || _xAxis.labelPosition == .bottomInside
            || _xAxis.labelPosition == .bothSided)
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }
        
        context.restoreGState()
    }
    
    fileprivate var _limitLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open override func renderLimitLines(context: CGContext)
    {
        var limitLines = _xAxis.limitLines
        
        if (limitLines.count == 0)
        {
            return
        }
        
        context.saveGState()
        
        let trans = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        for (i in 0 ..< limitLines.count)
        {
            let l = limitLines[i]
            
            if !l.isEnabled
            {
                continue
            }

            position.x = 0.0
            position.y = CGFloat(l.limit)
            position = position.applying(trans)
            
            _limitLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _limitLineSegmentsBuffer[0].y = position.y
            _limitLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _limitLineSegmentsBuffer[1].y = position.y
            
            context.setStrokeColor(l.lineColor.cgColor)
            context.setLineWidth(l.lineWidth)
            if (l.lineDashLengths != nil)
            {
                CGContextSetLineDash(context, l.lineDashPhase, l.lineDashLengths!, l.lineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            CGContextStrokeLineSegments(context, _limitLineSegmentsBuffer, 2)
            
            let label = l.label
            
            // if drawing the limit-value label is enabled
            if (label.characters.count > 0)
            {
                let labelLineHeight = l.valueFont.lineHeight
                
                let xOffset: CGFloat = 4.0 + l.xOffset
                let yOffset: CGFloat = l.lineWidth + labelLineHeight + l.yOffset
                
                if (l.labelPosition == .rightTop)
                {
                    ChartUtils.drawText(context: context,
                        text: label,
                        point: CGPoint(
                            x: viewPortHandler.contentRight - xOffset,
                            y: position.y - yOffset),
                        align: .right,
                        attributes: [NSFontAttributeName: l.valueFont, NSForegroundColorAttributeName: l.valueTextColor])
                }
                else if (l.labelPosition == .rightBottom)
                {
                    ChartUtils.drawText(context: context,
                        text: label,
                        point: CGPoint(
                            x: viewPortHandler.contentRight - xOffset,
                            y: position.y + yOffset - labelLineHeight),
                        align: .right,
                        attributes: [NSFontAttributeName: l.valueFont, NSForegroundColorAttributeName: l.valueTextColor])
                }
                else if (l.labelPosition == .leftTop)
                {
                    ChartUtils.drawText(context: context,
                        text: label,
                        point: CGPoint(
                            x: viewPortHandler.contentLeft + xOffset,
                            y: position.y - yOffset),
                        align: .left,
                        attributes: [NSFontAttributeName: l.valueFont, NSForegroundColorAttributeName: l.valueTextColor])
                }
                else
                {
                    ChartUtils.drawText(context: context,
                        text: label,
                        point: CGPoint(
                            x: viewPortHandler.contentLeft + xOffset,
                            y: position.y + yOffset - labelLineHeight),
                        align: .left,
                        attributes: [NSFontAttributeName: l.valueFont, NSForegroundColorAttributeName: l.valueTextColor])
                }
            }
        }
        
        context.restoreGState()
    }
}
