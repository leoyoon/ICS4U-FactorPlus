//
//  ChartXAxisRenderer.swift
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

open class ChartXAxisRenderer: ChartAxisRendererBase
{
    internal var _xAxis: ChartXAxis!
  
    public init(viewPortHandler: ChartViewPortHandler, xAxis: ChartXAxis, transformer: ChartTransformer!)
    {
        super.init(viewPortHandler: viewPortHandler, transformer: transformer)
        
        _xAxis = xAxis
    }
    
    open func computeAxis(xValAverageLength: Double, xValues: [String?])
    {
        var a = ""
        
        let max = Int(round(xValAverageLength + Double(_xAxis.spaceBetweenLabels)))
        
        for (i in 0 ..< max)
        {
            a += "h"
        }
        
        let widthText = a as NSString
        
        let labelSize = widthText.size(attributes: [NSFontAttributeName: _xAxis.labelFont])
        
        let labelWidth = labelSize.width
        let labelHeight = labelSize.height
        
        let labelRotatedSize = ChartUtils.sizeOfRotatedRectangle(labelSize, degrees: _xAxis.labelRotationAngle)
        
        _xAxis.labelWidth = labelWidth
        _xAxis.labelHeight = labelHeight
        _xAxis.labelRotatedWidth = labelRotatedSize.width
        _xAxis.labelRotatedHeight = labelRotatedSize.height
        
        _xAxis.values = xValues
    }
    
    open override func renderAxisLabels(context: CGContext)
    {
        if (!_xAxis.isEnabled || !_xAxis.isDrawLabelsEnabled)
        {
            return
        }
        
        let yOffset = _xAxis.yOffset
        
        if (_xAxis.labelPosition == .top)
        {
            drawLabels(context: context, pos: viewPortHandler.contentTop - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))
        }
        else if (_xAxis.labelPosition == .topInside)
        {
            drawLabels(context: context, pos: viewPortHandler.contentTop + yOffset + _xAxis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 1.0))
        }
        else if (_xAxis.labelPosition == .bottom)
        {
            drawLabels(context: context, pos: viewPortHandler.contentBottom + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))
        }
        else if (_xAxis.labelPosition == .bottomInside)
        {
            drawLabels(context: context, pos: viewPortHandler.contentBottom - yOffset - _xAxis.labelRotatedHeight, anchor: CGPoint(x: 0.5, y: 0.0))
        }
        else
        { // BOTH SIDED
            drawLabels(context: context, pos: viewPortHandler.contentTop - yOffset, anchor: CGPoint(x: 0.5, y: 1.0))
            drawLabels(context: context, pos: viewPortHandler.contentBottom + yOffset, anchor: CGPoint(x: 0.5, y: 0.0))
        }
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
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentTop
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentTop
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }

        if (_xAxis.labelPosition == .bottom
                || _xAxis.labelPosition == .bottomInside
                || _xAxis.labelPosition == .bothSided)
        {
            _axisLineSegmentsBuffer[0].x = viewPortHandler.contentLeft
            _axisLineSegmentsBuffer[0].y = viewPortHandler.contentBottom
            _axisLineSegmentsBuffer[1].x = viewPortHandler.contentRight
            _axisLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
            CGContextStrokeLineSegments(context, _axisLineSegmentsBuffer, 2)
        }
        
        context.restoreGState()
    }
    
    /// draws the x-labels on the specified y-position
    internal func drawLabels(context: CGContext, pos: CGFloat, anchor: CGPoint)
    {
        let paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paraStyle.alignment = .center
        
        let labelAttrs = [NSFontAttributeName: _xAxis.labelFont,
            NSForegroundColorAttributeName: _xAxis.labelTextColor,
            NSParagraphStyleAttributeName: paraStyle]
        let labelRotationAngleRadians = _xAxis.labelRotationAngle * ChartUtils.Math.FDEG2RAD
        
        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        var labelMaxSize = CGSize()
        
        if (_xAxis.isWordWrapEnabled)
        {
            labelMaxSize.width = _xAxis.wordWrapWidthPercent * valueToPixelMatrix.a
        }
        
        for (var i = _minX, maxX = min(_maxX + 1, _xAxis.values.count); i < maxX; i += _xAxis.axisLabelModulus)
        {
            let label = _xAxis.values[i]
            if (label == nil)
            {
                continue
            }
            
            position.x = CGFloat(i)
            position.y = 0.0
            position = position.applying(valueToPixelMatrix)
            
            if (viewPortHandler.isInBoundsX(position.x))
            {
                let labelns = label! as NSString
                
                if (_xAxis.isAvoidFirstLastClippingEnabled)
                {
                    // avoid clipping of the last
                    if (i == _xAxis.values.count - 1 && _xAxis.values.count > 1)
                    {
                        let width = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        
                        if (width > viewPortHandler.offsetRight * 2.0
                            && position.x + width > viewPortHandler.chartWidth)
                        {
                            position.x -= width / 2.0
                        }
                    }
                    else if (i == 0)
                    { // avoid clipping of the first
                        let width = labelns.boundingRect(with: labelMaxSize, options: .usesLineFragmentOrigin, attributes: labelAttrs, context: nil).size.width
                        position.x += width / 2.0
                    }
                }
                
                drawLabel(context: context, label: label!, xIndex: i, x: position.x, y: pos, attributes: labelAttrs, constrainedToSize: labelMaxSize, anchor: anchor, angleRadians: labelRotationAngleRadians)
            }
        }
    }
    
    internal func drawLabel(context: CGContext, label: String, xIndex: Int, x: CGFloat, y: CGFloat, attributes: [String: NSObject], constrainedToSize: CGSize, anchor: CGPoint, angleRadians: CGFloat)
    {
        let formattedLabel = _xAxis.valueFormatter?.stringForXValue(xIndex, original: label, viewPortHandler: viewPortHandler) ?? label
        ChartUtils.drawMultilineText(context: context, text: formattedLabel, point: CGPoint(x: x, y: y), attributes: attributes, constrainedToSize: constrainedToSize, anchor: anchor, angleRadians: angleRadians)
    }
    
    fileprivate var _gridLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open override func renderGridLines(context: CGContext)
    {
        if (!_xAxis.isDrawGridLinesEnabled || !_xAxis.isEnabled)
        {
            return
        }
        
        context.saveGState()

        if (!_xAxis.gridAntialiasEnabled)
        {
            context.setShouldAntialias(false)
        }

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
        
        let valueToPixelMatrix = transformer.valueToPixelMatrix
        
        var position = CGPoint(x: 0.0, y: 0.0)
        
        for (var i = _minX; i <= _maxX; i += _xAxis.axisLabelModulus)
        {
            position.x = CGFloat(i)
            position.y = 0.0
            position = position.applying(valueToPixelMatrix)
            
            if (position.x >= viewPortHandler.offsetLeft
                && position.x <= viewPortHandler.chartWidth)
            {
                _gridLineSegmentsBuffer[0].x = position.x
                _gridLineSegmentsBuffer[0].y = viewPortHandler.contentTop
                _gridLineSegmentsBuffer[1].x = position.x
                _gridLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
                CGContextStrokeLineSegments(context, _gridLineSegmentsBuffer, 2)
            }
        }
        
        context.restoreGState()
    }
    
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

            position.x = CGFloat(l.limit)
            position.y = 0.0
            position = position.applying(trans)
            
            renderLimitLineLine(context: context, limitLine: l, position: position)
            renderLimitLineLabel(context: context, limitLine: l, position: position, yOffset: 2.0 + l.yOffset)
        }
        
        context.restoreGState()
    }
    
    fileprivate var _limitLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    open func renderLimitLineLine(context: CGContext, limitLine: ChartLimitLine, position: CGPoint)
    {
        _limitLineSegmentsBuffer[0].x = position.x
        _limitLineSegmentsBuffer[0].y = viewPortHandler.contentTop
        _limitLineSegmentsBuffer[1].x = position.x
        _limitLineSegmentsBuffer[1].y = viewPortHandler.contentBottom
        
        context.setStrokeColor(limitLine.lineColor.cgColor)
        context.setLineWidth(limitLine.lineWidth)
        if (limitLine.lineDashLengths != nil)
        {
            CGContextSetLineDash(context, limitLine.lineDashPhase, limitLine.lineDashLengths!, limitLine.lineDashLengths!.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        CGContextStrokeLineSegments(context, _limitLineSegmentsBuffer, 2)
    }
    
    open func renderLimitLineLabel(context: CGContext, limitLine: ChartLimitLine, position: CGPoint, yOffset: CGFloat)
    {
        let label = limitLine.label
        
        // if drawing the limit-value label is enabled
        if (label.characters.count > 0)
        {
            let labelLineHeight = limitLine.valueFont.lineHeight
            
            let xOffset: CGFloat = limitLine.lineWidth + limitLine.xOffset
            
            if (limitLine.labelPosition == .rightTop)
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x + xOffset,
                        y: viewPortHandler.contentTop + yOffset),
                    align: .left,
                    attributes: [NSFontAttributeName: limitLine.valueFont, NSForegroundColorAttributeName: limitLine.valueTextColor])
            }
            else if (limitLine.labelPosition == .rightBottom)
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x + xOffset,
                        y: viewPortHandler.contentBottom - labelLineHeight - yOffset),
                    align: .left,
                    attributes: [NSFontAttributeName: limitLine.valueFont, NSForegroundColorAttributeName: limitLine.valueTextColor])
            }
            else if (limitLine.labelPosition == .leftTop)
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x - xOffset,
                        y: viewPortHandler.contentTop + yOffset),
                    align: .right,
                    attributes: [NSFontAttributeName: limitLine.valueFont, NSForegroundColorAttributeName: limitLine.valueTextColor])
            }
            else
            {
                ChartUtils.drawText(context: context,
                    text: label,
                    point: CGPoint(
                        x: position.x - xOffset,
                        y: viewPortHandler.contentBottom - labelLineHeight - yOffset),
                    align: .right,
                    attributes: [NSFontAttributeName: limitLine.valueFont, NSForegroundColorAttributeName: limitLine.valueTextColor])
            }
        }
    }

}
