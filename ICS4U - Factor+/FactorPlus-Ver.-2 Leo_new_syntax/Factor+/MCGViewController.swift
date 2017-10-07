//
//  MultipleChoice2ViewController.swift
//  Factor+
//
//  Created by Jia Long Ma on 2015-11-03.
//  Copyright © 2015 LYM. All rights reserved.
//
//  Credits to:
//  Taehyun Lee: For integration into the UI and separating the algorithmn into functions
//  Leo Yoon: For integration of the buttons around the algorithm and implementing the pause function
//  John Ma: For creating the base algorithm that generates graphing multiple choice answers and returns the correct index
//
// Commentor: John Ma

import UIKit
import Charts

class MultipleChoice2ViewController: UIViewController {
    
    //The following outlets link the MultipleChoice2ViewController class to the graphing multiple choice view controller
    
    @IBOutlet weak var rotateLabel: UILabel!
    @IBOutlet weak var progressMCG: UIProgressView!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var buttonFrame: UIImageView!    //the blue background behind the buttons
    @IBOutlet weak var coverUpButton: UIButton!
    @IBOutlet weak var graphView: LineChartView!    //a custom view from IOS Charts API that display a line graph
    @IBOutlet weak var graphView2: LineChartView!
    @IBOutlet weak var pauseImage: UIImageView!
    
    @IBOutlet var choiceButtons: Array<UIButton>? // Since the choice buttons on the view controller are identical, they
                                                  // can be stored in a button array. Each of the buttons in the view controller
                                                  // must be linked in the correct order to take up spots in the array
    
    //variables that are used in the class are declared
    
    var rightAnsIndex = Int(), numQuestions = Int(), ttlScore = Int() //rightAnsIndex stores the index of the correct answer
                                                                      //numQuestions stores the number of questions answered
                                                                      //ttlScore stores the basic form of the current score
                                                                      
    var fromPause: Bool = false //Checks whether or not the view controller was accessed through the pause screen
    var MultipleChoice = MultipleCGraph() //object that will call upon the MultipleCGraph class in another file
    var choice = [String]() //String array that will store possible multiple choice answers
    var xValues = [String]() //Stores x values that will be inputed into a graphing function (x values must be strings)
    var yValues = [Double]() //Stores y values that will be inputed into a graphing function (y values must be doubles)
    
    
    //Depending on the multiple choice button clicked, the function "buttonClicked" will be called upon with the parameters 
    //being the choice button's index in the "choiceButtons" Array
    
    @IBAction func choice1Clicked(_ sender: AnyObject) {
    
        buttonClicked(0)

    }
    @IBAction func choice2Clicked(_ sender: AnyObject) {
       
        buttonClicked(1)

    }
    @IBAction func choice3Clicked(_ sender: AnyObject) {
    
        buttonClicked(2)

    }
    @IBAction func choice4Clicked(_ sender: AnyObject) {

        buttonClicked(3)

    }
    
    //In the buttonClicked function, a button index is recieved and the general output for clicking a multiple choice button
    //is activated
    
    func buttonClicked(_ buttonIndex: Int) { //Start of buttonClicked method
        
        if (checkForRightAnswer(buttonIndex) == true) { //calls upon checkForRightAnswer method to see if button clicked has
                                                        //the right answer string
            
            choiceButtons![buttonIndex].backgroundColor = UIColor.green    //if correct, set the button to green
            ttlScore += 1                                            //increment number of answers correctly chosen
        }
        else { //if the choice button is incorrect
            
            choiceButtons![buttonIndex].backgroundColor = UIColor.red      //if incorrect, set the button to red
            
            //then check every other answer to see if they are correct, and highlight the correct answer in green
            choiceButtons![rightAnsIndex].backgroundColor = UIColor.green
            
        }
        
        buttonFrame.isHidden = false     //show the button frame
        nextButton.isHidden = false      //show the 'next' button
        pauseButton.isHidden = true      //hide the 'pause' button to prevent the question from resetting
        coverUpButton.isHidden = false   //show the 'coverUp' button which is to prevent other answer buttons from
                                       //being clicked once the question is answered
        pauseImage.isHidden = true       //hide the 'pause' image as well
        rotateLabel.isHidden = true      
        
    }
    
    @IBAction func pauseClicked(_ sender: AnyObject) { //opens pause screen when called upon
        
        performSegue(withIdentifier: "pauseMCG", sender: sender)
    }

    @IBAction func nextButtonClicked(_ sender: AnyObject) { // Upon clicking the next button, the following buttons and methods are affected
        
        resetColours() //Calls upon resetColours method to reset button colours
        changeProgress() //call upon changeProgress method
        makeMultipleChoice() //call upon the makeMultipleChoice method
        pauseButton.isHidden = false //Reveals pause button
        buttonFrame.isHidden = true //Hides the frame of the next button
        nextButton.isHidden = true //Hides next button
        coverUpButton.isHidden = true //Hides coverUpButton (Prevents user from spamming choice buttons)
        pauseImage.isHidden = false //Shows the pause button image
        rotateLabel.isHidden = false //Shows the "Rotate Screen for Better View" Text

    }
    
    func changeProgress() { //Calling upon this method updates the progress of the Multiple Choice Graphing game mode
        numQuestions += 1 //The question number increments
        let temp = Double(numQuestions)/10 //Stores percentage of questions answered
        progressMCG.setProgress(Float(temp), animated: true) //Uses var temp to change the progress bar
        
        MultipleChoice = MultipleCGraph() //Creates a MultipleCGraph object
        
        endGame() //Calls upon endGame method to check if the game has ended
    }
    
    func resetColours() { //this method resets colours on the buttons
        
        for (i in 0 ..< 4) { //For choiceButtons 1 to 4, the colour is reset using this for loop
            
            choiceButtons![i].backgroundColor = UIColor(red: 222/255.0, green: 168/255.0, blue: 160/255.0, alpha: 1.0)
        }
        
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        var temp = Double(numQuestions)/10
        progressMCG.setProgress(Float(temp), animated: false)
        coverUpButton.isHidden = true
        
        graphView.zoom(1.2, scaleY: 1, x: 120, y: 64) //zooms the graphView, which is a LineChartView by a certain percentage about the indicated point
        graphView.dragEnabled = false //disables user interaction with graphView via dragging
        graphView.doubleTapToZoomEnabled = false //disables user interaction with graphView via double tapping
        
        graphView2.zoom(1.2, scaleY: 1, x: 120, y: 64)
        graphView2.dragEnabled = false
        graphView2.doubleTapToZoomEnabled = false
        
        let yAxis = ChartLimitLine(limit: 0) //yAxis is declared as a ChartLimitLine object with its value set to 0
        let xAxis = ChartLimitLine(limit: 6.0) //xAxis is declared as a ChartLimitLine object with its x-index at 6
        //this actually creates the yAxis
        //It is declared as xAxis due to it being defined from the x-axis (x-index is the x value, and the value stored in the x-index is the y value)
        graphView.leftAxis.addLimitLine(yAxis) //adds a line through the y-axis
        graphView.xAxis.addLimitLine(xAxis) //adds a line through the x-axis
        graphView2.leftAxis.addLimitLine(yAxis)
        graphView2.xAxis.addLimitLine(xAxis)
    
        graphView.rightAxis.labelFont = UIFont(name: "", size: 0)! //lables on the right side of the graph is set to have a font of zero, making them invisible
        graphView2.rightAxis.labelFont = UIFont(name: "", size: 0)!
        
        if (fromPause == true) {
            
            setChart(xValues, yval: yValues) //when coming from PauseViewController as fromPause set to true, the x-values and y-values that were stored in the PauseViewController is set to be the xValues and yValues of this class
            //chart with x-value and y-value from pause screen is made
            
            for (i in 0 ..< 4) {
                
                choiceButtons![i].setTitle(choice[i], for: UIControlState())

            }
            
        }
        else { //if not from PauseViewController, new x-values and y-values are made
            var graphPoint = MultipleCGraph.getGraphOfPointsMC(MultipleChoice) 
        
            let xval = graphPoint().getXVal()
            let yval = graphPoint().getYVal()
            setChart(xval, yval:yval)
            makeMultipleChoice()
        }
        // Do any additional setup after loading the view.
    }

    //http://www.appcoda.com/ios-charts-api-tutorial/
    func setChart(_ xval:[String], yval:[Double]) {
        
        var dataEntries: [ChartDataEntry] = [] //ChartDataEntry objects store the y-value for a specific index
        
        for i in 0..<xval.count {
            let dataEntry = ChartDataEntry(value: yval[i], xIndex: i)
            dataEntries.append(dataEntry)
        }
        
        let xvalDataSet = LineChartDataSet(yVals: dataEntries, label: "") //using the array of ChartDataEntry, LineChartDataSet object is created
        let xvalData = LineChartData(xVals: xval, dataSet: xvalDataSet) //by merging the x-values and y-values into one, LineChartData object is created
        graphView.data = xvalData //the LineChartData is set as the data of graphView
        graphView.data?.setValueFont(UIFont(name:"Helvetica Neuve", size: 12)) //this sets the font of the displayed y-values
        graphView.setDescriptionTextPosition(x: CGFloat(10000), y: CGFloat(100000)) //this moves the description text label of the graph to be placed out of the graphView
     
        graphView2.data = xvalData
        graphView2.data?.setValueFont(UIFont(name:"Helvetica Neuve", size: 12))
        graphView2.setDescriptionTextPosition(x: CGFloat(10000), y: CGFloat(100000))
        
        for (i in 0 ..< 12) { //the x-values and y-values are set to attributes xValues and yValues so that the coordinates can be transferred between PauseViewController and MCGViewController
          
            xValues.insert(xval[i], at: i)
            yValues.insert(yval[i], at: i)
        }
        
    }

    func makeMultipleChoice() { //This method creates a multiple choice string array and stores puts them on buttons
        
        rightAnsIndex = MultipleChoice.getRightIndex() //Returns correct answers
        choice = MultipleChoice.getChoice() //Recieves string array
        
        for (i in 0 ..< 4) { //Sets the strings in the array to corresponding buttons
            
            choiceButtons![i].setTitle(choice[i], for: UIControlState())
            
        }
        
    }
    
    func checkForRightAnswer(_ buttonNumber: Int) -> Bool { //This method calls returns a boolean depending on the index entered
        
        //if the user chose the correct answer
        if ((buttonNumber) == rightAnsIndex) {
            
            return true
        }
            //if the user's choice is incorrect
        else {
            
            return false
            
        } //end of 'if else' statement
    }
    
    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
    }
    
    func endGame() { //This method checks if the game has ended. If it has, then the end screen will be loaded
        
        if(numQuestions == 10) { //If the question count reaches 10, then the end screen segue is loaded
            
            performSegue(withIdentifier: "endMCG", sender: self)
        }
        else { //Otherwise load the current question again
            
            let graphPoint = MultipleCGraph.getGraphOfPointsMC(MultipleChoice)
            
            let xval = graphPoint().getXVal()
            let yval = graphPoint().getYVal()
            setChart(xval, yval: yval)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) { //this method brings up either pause screen or end screen depending on the identifier
        
        if(segue.identifier == "pauseMCG") { //if the identifier is pauseMCG, all output values (values on-screen) and the score is stored in PauseViewController
            
            let pvc = segue.destination as! PauseViewController
            pvc.score = ttlScore
            pvc.numQuestion = numQuestions
            pvc.type = "Multiple Choice Graph"
            pvc.rightAnswerIndex = rightAnsIndex
            
            for (var i = 0; i <= 3; i += 1) {
                
                pvc.multipleChoiceChoices.insert(choice[i], at: i)
            }
            
            for (i in 0 ..< 12) {
                
                pvc.xval.insert(xValues[i], at: i)
                pvc.yval.insert(yValues[i], at: i)
            }
        }
        else if(segue.identifier == "endMCG") { //if the identifer is endMCG, the score is set as numCorrect variable of EndViewController
            
            let evc = segue.destination as! EndViewController
            evc.numCorrect = ttlScore
            evc.type = "Multiple Choice Graph"
        }
    }

}
