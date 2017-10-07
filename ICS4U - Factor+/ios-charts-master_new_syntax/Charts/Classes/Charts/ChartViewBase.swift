//
//  ChartViewBase.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 23/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//
//  Based on https://github.com/PhilJay/MPAndroidChart/commit/c42b880

import Foundation
import UIKit

@objc
public protocol ChartViewDelegate
{
    /// Called when a value has been selected inside the chart.
    /// - parameter entry: The selected Entry.
    /// - parameter dataSetIndex: The index in the datasets array of the data object the Entrys DataSet is in.
    @objc optional func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, dataSetIndex: Int, highlight: ChartHighlight)
    
    // Called when nothing has been selected or an "un-select" has been made.
    @objc optional func chartValueNothingSelected(_ chartView: ChartViewBase)
    
    // Callbacks when the chart is scaled / zoomed via pinch zoom gesture.
    @objc optional func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat)
    
    // Callbacks when the chart is moved / translated via drag gesture.
    @objc optional func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat)
}

open class ChartViewBase: UIView, ChartDataProvider, ChartAnimatorDelegate
{
    // MARK: - Properties
    
    /// the default value formatter
    internal var _defaultValueFormatter: NumberFormatter = ChartUtils.defaultValueFormatter()
    
    /// object that holds all data that was originally set for the chart, before it was modified or any filtering algorithms had been applied
    internal var _data: ChartData!
    
    /// Flag that indicates if highlighting per tap (touch) is enabled
    fileprivate var _highlightPerTapEnabled = true
    
    /// If set to true, chart continues to scroll after touch up
    open var dragDecelerationEnabled = true
    
    /// Deceleration friction coefficient in [0 ; 1] interval, higher values indicate that speed will decrease slowly, for example if it set to 0, it will stop immediately.
    /// 1 is an invalid value, and will be converted to 0.999 automatically.
    fileprivate var _dragDecelerationFrictionCoef: CGFloat = 0.9
    
    /// Font object used for drawing the description text (by default in the bottom right corner of the chart)
    open var descriptionFont: UIFont? = UIFont(name: "HelveticaNeue", size: 9.0)
    
    /// Text color used for drawing the description text
    open var descriptionTextColor: UIColor? = UIColor.black
    
    /// Text align used for drawing the description text
    open var descriptionTextAlign: NSTextAlignment = NSTextAlignment.right
    
    /// Custom position for the description text in pixels on the screen.
    open var descriptionTextPosition: CGPoint? = nil
    
    /// font object for drawing the information text when there are no values in the chart
    open var infoFont: UIFont! = UIFont(name: "HelveticaNeue", size: 12.0)
    open var infoTextColor: UIColor! = UIColor(red: 247.0/255.0, green: 189.0/255.0, blue: 51.0/255.0, alpha: 1.0) // orange
    
    /// description text that appears in the bottom right corner of the chart
    open var descriptionText = "Description"
    
    /// flag that indicates if the chart has been fed with data yet
    internal var _dataNotSet = true
    
    /// if true, units are drawn next to the values in the chart
    internal var _drawUnitInChart = false
    
    /// the number of x-values the chart displays
    internal var _deltaX = CGFloat(1.0)
    
    internal var _chartXMin = Double(0.0)
    internal var _chartXMax = Double(0.0)
    
    /// the legend object containing all data associated with the legend
    internal var _legend: ChartLegend!
    
    /// delegate to receive chart events
    open weak var delegate: ChartViewDelegate?
    
    /// text that is displayed when the chart is empty
    open var noDataText = "No chart data available."
    
    /// text that is displayed when the chart is empty that describes why the chart is empty
    open var noDataTextDescription: String?
    
    internal var _legendRenderer: ChartLegendRenderer!
    
    /// object responsible for rendering the data
    open var renderer: ChartDataRendererBase?
    
    internal var _highlighter: ChartHighlighter?
    
    /// object that manages the bounds and drawing constraints of the chart
    internal var _viewPortHandler: ChartViewPortHandler!
    
    /// object responsible for animations
    internal var _animator: ChartAnimator!
    
    /// flag that indicates if offsets calculation has already been done or not
    fileprivate var _offsetsCalculated = false
    
    /// array of Highlight objects that reference the highlighted slices in the chart
    internal var _indicesToHighlight = [ChartHighlight]()
    
    /// if set to true, the marker is drawn when a value is clicked
    open var drawMarkers = true
    
    /// the view that represents the marker
    open var marker: ChartMarker?
    
    fileprivate var _interceptTouchEvents = false
    
    /// An extra offset to be appended to the viewport's top
    open var extraTopOffset: CGFloat = 0.0
    
    /// An extra offset to be appended to the viewport's right
    open var extraRightOffset: CGFloat = 0.0
    
    /// An extra offset to be appended to the viewport's bottom
    open var extraBottomOffset: CGFloat = 0.0
    
    /// An extra offset to be appended to the viewport's left
    open var extraLeftOffset: CGFloat = 0.0
    
    open func setExtraOffsets(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat)
    {
        extraLeftOffset = left
        extraTopOffset = top
        extraRightOffset = right
        extraBottomOffset = bottom
    }
    
    // MARK: - Initializers
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
        initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        initialize()
    }
    
    deinit
    {
        self.removeObserver(self, forKeyPath: "bounds")
        self.removeObserver(self, forKeyPath: "frame")
    }
    
    internal func initialize()
    {
        _animator = ChartAnimator()
        _animator.delegate = self

        _viewPortHandler = ChartViewPortHandler()
        _viewPortHandler.setChartDimens(width: bounds.size.width, height: bounds.size.height)
        
        _legend = ChartLegend()
        _legendRenderer = ChartLegendRenderer(viewPortHandler: _viewPortHandler, legend: _legend)
        
        self.addObserver(self, forKeyPath: "bounds", options: .new, context: nil)
        self.addObserver(self, forKeyPath: "frame", options: .new, context: nil)
    }
    
    // MARK: - ChartViewBase
    
    /// The data for the chart
    open var data: ChartData?
    {
        get
        {
            return _data
        }
        set
        {
            if newValue == nil
            {
                print("Charts: data argument is nil on setData()", terminator: "\n")
                return
            }
            
            _dataNotSet = false
            _offsetsCalculated = false
            _data = newValue
            
            // calculate how many digits are needed
            calculateFormatter(min: _data.getYMin(), max: _data.getYMax())
            
            notifyDataSetChanged()
        }
    }
    
    /// Clears the chart from all data (sets it to null) and refreshes it (by calling setNeedsDisplay()).
    open func clear()
    {
        _data = nil
        _dataNotSet = true
        _indicesToHighlight.removeAll()
        setNeedsDisplay()
    }
    
    /// Removes all DataSets (and thereby Entries) from the chart. Does not remove the x-values. Also refreshes the chart by calling setNeedsDisplay().
    open func clearValues()
    {
        if (_data !== nil)
        {
            _data.clearValues()
        }
        setNeedsDisplay()
    }
    
    /// - returns: true if the chart is empty (meaning it's data object is either null or contains no entries).
    open func isEmpty() -> Bool
    {
        if (_data == nil)
        {
            return true
        }
        else
        {
            
            if (_data.yValCount <= 0)
            {
                return true
            }
            else
            {
                return false
            }
        }
    }
    
    /// Lets the chart know its underlying data has changed and should perform all necessary recalculations.
    /// It is crucial that this method is called everytime data is changed dynamically. Not calling this method can lead to crashes or unexpected behaviour.
    open func notifyDataSetChanged()
    {
        fatalError("notifyDataSetChanged() cannot be called on ChartViewBase")
    }
    
    /// calculates the offsets of the chart to the border depending on the position of an eventual legend or depending on the length of the y-axis and x-axis labels and their position
    internal func calculateOffsets()
    {
        fatalError("calculateOffsets() cannot be called on ChartViewBase")
    }
    
    /// calcualtes the y-min and y-max value and the y-delta and x-delta value
    internal func calcMinMax()
    {
        fatalError("calcMinMax() cannot be called on ChartViewBase")
    }
    
    /// calculates the required number of digits for the values that might be drawn in the chart (if enabled), and creates the default value formatter
    internal func calculateFormatter(min: Double, max: Double)
    {
        // check if a custom formatter is set or not
        var reference = Double(0.0)
        
        if (_data == nil || _data.xValCount < 2)
        {
            let absMin = fabs(min)
            let absMax = fabs(max)
            reference = absMin > absMax ? absMin : absMax
        }
        else
        {
            reference = fabs(max - min)
        }
        
        let digits = ChartUtils.decimals(reference)
    
        _defaultValueFormatter.maximumFractionDigits = digits
        _defaultValueFormatter.minimumFractionDigits = digits
    }
    
    open override func draw(_ rect: CGRect)
    {
        let optionalContext = UIGraphicsGetCurrentContext()
        guard let context = optionalContext else { return }
        
        let frame = self.bounds

        if (_dataNotSet || _data === nil || _data.yValCount == 0)
        { // check if there is data
            
            context.saveGState()
            
            // if no data, inform the user
            
            ChartUtils.drawText(context: context, text: noDataText, point: CGPoint(x: frame.width / 2.0, y: frame.height / 2.0), align: .center, attributes: [NSFontAttributeName: infoFont, NSForegroundColorAttributeName: infoTextColor])
            
            if (noDataTextDescription != nil && (noDataTextDescription!).characters.count > 0)
            {   
                let textOffset = infoFont.lineHeight
                
                ChartUtils.drawText(context: context, text: noDataTextDescription!, point: CGPoint(x: frame.width / 2.0, y: frame.height / 2.0 + textOffset), align: .center, attributes: [NSFontAttributeName: infoFont, NSForegroundColorAttributeName: infoTextColor])
            }
            
            return
        }
        
        if (!_offsetsCalculated)
        {
            calculateOffsets()
            _offsetsCalculated = true
        }
    }
    
    /// draws the description text in the bottom right corner of the chart
    internal func drawDescription(context: CGContext)
    {
        if (descriptionText.lengthOfBytes(using: String.Encoding.utf16) == 0)
        {
            return
        }
        
        let frame = self.bounds
        
        var attrs = [String : AnyObject]()
        
        var font = descriptionFont
        
        if (font == nil)
        {
            #if os(tvOS)
                // 23 is the smallest recommened font size on the TV
                font = UIFont.systemFontOfSize(23, weight: UIFontWeightMedium)
            #else
                font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
            #endif
        }
        
        attrs[NSFontAttributeName] = font
        attrs[NSForegroundColorAttributeName] = descriptionTextColor

        if descriptionTextPosition == nil
        {
            ChartUtils.drawText(
                context: context,
                text: descriptionText,
                point: CGPoint(
                    x: frame.width - _viewPortHandler.offsetRight - 10.0,
                    y: frame.height - _viewPortHandler.offsetBottom - 10.0 - (font?.lineHeight ?? 0.0)),
                align: descriptionTextAlign,
                attributes: attrs)
        }
        else
        {
            ChartUtils.drawText(
                context: context,
                text: descriptionText,
                point: descriptionTextPosition!,
                align: descriptionTextAlign,
                attributes: attrs)
        }
    }
    
    // MARK: - Highlighting
    
    /// - returns: the array of currently highlighted values. This might an empty if nothing is highlighted.
    open var highlighted: [ChartHighlight]
    {
        return _indicesToHighlight
    }
    
    /// Set this to false to prevent values from being highlighted by tap gesture.
    /// Values can still be highlighted via drag or programmatically.
    /// - default: true
    open var highlightPerTapEnabled: Bool
    {
        get { return _highlightPerTapEnabled }
        set { _highlightPerTapEnabled = newValue }
    }
    
    /// Returns true if values can be highlighted via tap gesture, false if not.
    open var isHighLightPerTapEnabled: Bool
    {
        return highlightPerTapEnabled
    }
    
    /// Checks if the highlight array is null, has a length of zero or if the first object is null.
    /// - returns: true if there are values to highlight, false if there are no values to highlight.
    open func valuesToHighlight() -> Bool
    {
        return _indicesToHighlight.count > 0
    }

    /// Highlights the values at the given indices in the given DataSets. Provide
    /// null or an empty array to undo all highlighting. 
    /// This should be used to programmatically highlight values. 
    /// This DOES NOT generate a callback to the delegate.
    open func highlightValues(_ highs: [ChartHighlight]?)
    {
        // set the indices to highlight
        _indicesToHighlight = highs ?? [ChartHighlight]()
        
        if (_indicesToHighlight.isEmpty)
        {
            self.lastHighlighted = nil
        }
        else
        {
            self.lastHighlighted = _indicesToHighlight[0];
        }

        // redraw the chart
        setNeedsDisplay()
    }
    
    
    /// Highlights the values represented by the provided Highlight object
    /// This DOES NOT generate a callback to the delegate.
    /// - parameter highlight: contains information about which entry should be highlighted
    open func highlightValue(_ highlight: ChartHighlight?)
    {
        highlightValue(highlight: highlight, callDelegate: false)
    }
    
    /// Highlights the value at the given x-index in the given DataSet.
    /// Provide -1 as the x-index to undo all highlighting.
    open func highlightValue(xIndex: Int, dataSetIndex: Int, callDelegate: Bool)
    {
        if (xIndex < 0 || dataSetIndex < 0 || xIndex >= _data.xValCount || dataSetIndex >= _data.dataSetCount)
        {
            highlightValue(highlight: nil, callDelegate: callDelegate)
        }
        else
        {
            highlightValue(highlight: ChartHighlight(xIndex: xIndex, dataSetIndex: dataSetIndex), callDelegate: callDelegate)
        }
    }

    /// Highlights the value selected by touch gesture.
    open func highlightValue(highlight: ChartHighlight?, callDelegate: Bool)
    {
        var entry: ChartDataEntry?
        var h = highlight
        
        if (h == nil)
        {
            _indicesToHighlight.removeAll(keepingCapacity: false)
        }
        else
        {
            // set the indices to highlight
            entry = _data.getEntryForHighlight(h!)
            if (entry === nil || entry!.xIndex != h?.xIndex)
            {
                h = nil
                entry = nil
                _indicesToHighlight.removeAll(keepingCapacity: false)
            }
            else
            {
                _indicesToHighlight = [h!]
            }
        }
        
        if (callDelegate && delegate != nil)
        {
            if (h == nil)
            {
                delegate!.chartValueNothingSelected?(self)
            }
            else
            {
                // notify the listener
                delegate!.chartValueSelected?(self, entry: entry!, dataSetIndex: h!.dataSetIndex, highlight: h!)
            }
        }
        
        // redraw the chart
        setNeedsDisplay()
    }
    
    /// The last value that was highlighted via touch.
    open var lastHighlighted: ChartHighlight?
  
    // MARK: - Markers

    /// draws all MarkerViews on the highlighted positions
    internal func drawMarkers(context: CGContext)
    {
        // if there is no marker view or drawing marker is disabled
        if (marker === nil || !drawMarkers || !valuesToHighlight())
        {
            return
        }

        for (var i = 0, count = _indicesToHighlight.count; i < count; i += 1)
        {
            let highlight = _indicesToHighlight[i]
            let xIndex = highlight.xIndex

            if (xIndex <= Int(_deltaX) && xIndex <= Int(_deltaX * _animator.phaseX))
            {
                let e = _data.getEntryForHighlight(highlight)
                if (e === nil || e!.xIndex != highlight.xIndex)
                {
                    continue
                }
                
                let pos = getMarkerPosition(entry: e!, highlight: highlight)

                // check bounds
                if (!_viewPortHandler.isInBounds(x: pos.x, y: pos.y))
                {
                    continue
                }

                // callbacks to update the content
                marker!.refreshContent(entry: e!, highlight: highlight)

                let markerSize = marker!.size
                if (pos.y - markerSize.height <= 0.0)
                {
                    let y = markerSize.height - pos.y
                    marker!.draw(context: context, point: CGPoint(x: pos.x, y: pos.y + y))
                }
                else
                {
                    marker!.draw(context: context, point: pos)
                }
            }
        }
    }
    
    /// - returns: the actual position in pixels of the MarkerView for the given Entry in the given DataSet.
    open func getMarkerPosition(entry: ChartDataEntry, highlight: ChartHighlight) -> CGPoint
    {
        fatalError("getMarkerPosition() cannot be called on ChartViewBase")
    }
    
    // MARK: - Animation
    
    /// - returns: the animator responsible for animating chart values.
    open var animator: ChartAnimator!
    {
        return _animator
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingX: an easing function for the animation on the x axis
    /// - parameter easingY: an easing function for the animation on the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingX: ChartEasingFunctionBlock?, easingY: ChartEasingFunctionBlock?)
    {
        _animator.animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easingX: easingX, easingY: easingY)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOptionX: the easing function for the animation on the x axis
    /// - parameter easingOptionY: the easing function for the animation on the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingOptionX: ChartEasingOption, easingOptionY: ChartEasingOption)
    {
        _animator.animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easingOptionX: easingOptionX, easingOptionY: easingOptionY)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easing: an easing function for the animation
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        _animator.animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easing: easing)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        _animator.animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easingOption: easingOption)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval)
    {
        _animator.animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration)
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter easing: an easing function for the animation
    open func animate(xAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        _animator.animate(xAxisDuration: xAxisDuration, easing: easing)
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(xAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        _animator.animate(xAxisDuration: xAxisDuration, easingOption: easingOption)
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    open func animate(xAxisDuration: TimeInterval)
    {
        _animator.animate(xAxisDuration: xAxisDuration)
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easing: an easing function for the animation
    open func animate(yAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        _animator.animate(yAxisDuration: yAxisDuration, easing: easing)
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(yAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        _animator.animate(yAxisDuration: yAxisDuration, easingOption: easingOption)
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    open func animate(yAxisDuration: TimeInterval)
    {
        _animator.animate(yAxisDuration: yAxisDuration)
    }
    
    // MARK: - Accessors

    /// - returns: the current y-max value across all DataSets
    open var chartYMax: Double
    {
        return _data.yMax
    }

    /// - returns: the current y-min value across all DataSets
    open var chartYMin: Double
    {
        return _data.yMin
    }
    
    open var chartXMax: Double
    {
        return _chartXMax
    }
    
    open var chartXMin: Double
    {
        return _chartXMin
    }
    
    open var xValCount: Int
    {
        return _data.xValCount
    }
    
    /// - returns: the total number of (y) values the chart holds (across all DataSets)
    open var valueCount: Int
    {
        return _data.yValCount
    }
    
    /// *Note: (Equivalent of getCenter() in MPAndroidChart, as center is already a standard in iOS that returns the center point relative to superview, and MPAndroidChart returns relative to self)*
    /// - returns: the center point of the chart (the whole View) in pixels.
    open var midPoint: CGPoint
    {
        let bounds = self.bounds
        return CGPoint(x: bounds.origin.x + bounds.size.width / 2.0, y: bounds.origin.y + bounds.size.height / 2.0)
    }
    
    open func setDescriptionTextPosition(x: CGFloat, y: CGFloat)
    {
        descriptionTextPosition = CGPoint(x: x, y: y)
    }
    
    /// - returns: the center of the chart taking offsets under consideration. (returns the center of the content rectangle)
    open var centerOffsets: CGPoint
    {
        return _viewPortHandler.contentCenter
    }
    
    /// - returns: the Legend object of the chart. This method can be used to get an instance of the legend in order to customize the automatically generated Legend.
    open var legend: ChartLegend
    {
        return _legend
    }
    
    /// - returns: the renderer object responsible for rendering / drawing the Legend.
    open var legendRenderer: ChartLegendRenderer!
    {
        return _legendRenderer
    }
    
    /// - returns: the rectangle that defines the borders of the chart-value surface (into which the actual values are drawn).
    open var contentRect: CGRect
    {
        return _viewPortHandler.contentRect
    }
    
    /// - returns: the x-value at the given index
    open func getXValue(_ index: Int) -> String!
    {
        if (_data == nil || _data.xValCount <= index)
        {
            return nil
        }
        else
        {
            return _data.xVals[index]
        }
    }
    
    /// Get all Entry objects at the given index across all DataSets.
    open func getEntriesAtIndex(_ xIndex: Int) -> [ChartDataEntry]
    {
        var vals = [ChartDataEntry]()
        
        for (var i = 0, count = _data.dataSetCount; i < count; i += 1)
        {
            let set = _data.getDataSetByIndex(i)
            let e = set.entryForXIndex(xIndex)
            if (e !== nil)
            {
                vals.append(e!)
            }
        }
        
        return vals
    }
    
    /// - returns: the percentage the given value has of the total y-value sum
    open func percentOfTotal(_ val: Double) -> Double
    {
        return val / _data.yValueSum * 100.0
    }
    
    /// - returns: the ViewPortHandler of the chart that is responsible for the
    /// content area of the chart and its offsets and dimensions.
    open var viewPortHandler: ChartViewPortHandler!
    {
        return _viewPortHandler
    }
    
    /// - returns: the bitmap that represents the chart.
    open func getChartImage(transparent: Bool) -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque || !transparent, UIScreen.main.scale)
        
        let context = UIGraphicsGetCurrentContext()
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: bounds.size)
        
        if (isOpaque || !transparent)
        {
            // Background color may be partially transparent, we must fill with white if we want to output an opaque image
            context?.setFillColor(UIColor.white.cgColor)
            context?.fill(rect)
            
            if (self.backgroundColor !== nil)
            {
                context?.setFillColor((self.backgroundColor?.cgColor)!)
                context?.fill(rect)
            }
        }
        
        if let context = context
        {
            layer.render(in: context)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image!
    }
    
    public enum ImageFormat
    {
        case jpeg
        case png
    }
    
    /// Saves the current chart state with the given name to the given path on
    /// the sdcard leaving the path empty "" will put the saved file directly on
    /// the SD card chart is saved as a PNG image, example:
    /// saveToPath("myfilename", "foldername1/foldername2")
    ///
    /// - parameter filePath: path to the image to save
    /// - parameter format: the format to save
    /// - parameter compressionQuality: compression quality for lossless formats (JPEG)
    ///
    /// - returns: true if the image was saved successfully
    open func saveToPath(_ path: String, format: ImageFormat, compressionQuality: Double) -> Bool
    {
        let image = getChartImage(transparent: format != .jpeg)

        var imageData: Data!
        switch (format)
        {
        case .png:
            imageData = UIImagePNGRepresentation(image)
            break
            
        case .jpeg:
            imageData = UIImageJPEGRepresentation(image, CGFloat(compressionQuality))
            break
        }

        return imageData.write(to: path, options: true)
    }
    
    #if !os(tvOS)
    /// Saves the current state of the chart to the camera roll
    open func saveToCameraRoll()
    {
        UIImageWriteToSavedPhotosAlbum(getChartImage(transparent: false), nil, nil, nil)
    }
    #endif
    
    internal typealias VoidClosureType = () -> ()
    internal var _sizeChangeEventActions = [VoidClosureType]()
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        if (keyPath == "bounds" || keyPath == "frame")
        {
            let bounds = self.bounds
            
            if (_viewPortHandler !== nil &&
                (bounds.size.width != _viewPortHandler.chartWidth ||
                bounds.size.height != _viewPortHandler.chartHeight))
            {
                _viewPortHandler.setChartDimens(width: bounds.size.width, height: bounds.size.height)
                
                // Finish any pending viewport changes
                while (!_sizeChangeEventActions.isEmpty)
                {
                    _sizeChangeEventActions.remove(at: 0)()
                }
                
                notifyDataSetChanged()
            }
        }
    }
    
    open func clearPendingViewPortChanges()
    {
        _sizeChangeEventActions.removeAll(keepingCapacity: false)
    }
    
    /// **default**: true
    /// - returns: true if chart continues to scroll after touch up, false if not.
    open var isDragDecelerationEnabled: Bool
        {
            return dragDecelerationEnabled
    }
    
    /// Deceleration friction coefficient in [0 ; 1] interval, higher values indicate that speed will decrease slowly, for example if it set to 0, it will stop immediately.
    /// 1 is an invalid value, and will be converted to 0.999 automatically.
    /// 
    /// **default**: true
    open var dragDecelerationFrictionCoef: CGFloat
    {
        get
        {
            return _dragDecelerationFrictionCoef
        }
        set
        {
            var val = newValue
            if (val < 0.0)
            {
                val = 0.0
            }
            if (val >= 1.0)
            {
                val = 0.999
            }
            
            _dragDecelerationFrictionCoef = val
        }
    }
    
    // MARK: - ChartAnimatorDelegate
    
    open func chartAnimatorUpdated(_ chartAnimator: ChartAnimator)
    {
        setNeedsDisplay()
    }
    
    open func chartAnimatorStopped(_ chartAnimator: ChartAnimator)
    {
        
    }
    
    // MARK: - Touches
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (!_interceptTouchEvents)
        {
            super.touchesBegan(touches, with: event)
        }
    }
    
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (!_interceptTouchEvents)
        {
            super.touchesMoved(touches, with: event)
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (!_interceptTouchEvents)
        {
            super.touchesEnded(touches, with: event)
        }
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (!_interceptTouchEvents)
        {
            super.touchesCancelled(touches, with: event)
        }
    }
}
