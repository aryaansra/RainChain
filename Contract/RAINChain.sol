
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RainChain
 * @dev A decentralized rainfall data management and prediction system
 * @author RainChain Development Team
 */
contract RainChain {
    
    // Struct to store rainfall data
    struct RainfallData {
        uint256 timestamp;
        uint256 rainfall; // rainfall in millimeters (scaled by 100 for precision)
        string location;
        address reporter;
        bool verified;
    }
    
    // Struct to store weather predictions
    struct WeatherPrediction {
        uint256 predictionId;
        uint256 timestamp;
        uint256 predictedRainfall;
        string location;
        address predictor;
        uint256 accuracy; // accuracy percentage (0-10000, where 10000 = 100%)
        bool resolved;
    }
    
    // State variables
    address public owner;
    uint256 public dataCount;
    uint256 public predictionCount;
    uint256 public constant VERIFICATION_REWARD = 0.001 ether;
    uint256 public constant PREDICTION_STAKE = 0.01 ether;
    
    // Mappings
    mapping(uint256 => RainfallData) public rainfallRecords;
    mapping(uint256 => WeatherPrediction) public predictions;
    mapping(address => bool) public verifiedReporters;
    mapping(address => uint256) public reputationScores;
    
    // Events
    event RainfallRecorded(uint256 indexed dataId, string location, uint256 rainfall, address reporter);
    event PredictionMade(uint256 indexed predictionId, string location, uint256 predictedRainfall, address predictor);
    event DataVerified(uint256 indexed dataId, address verifier);
    event PredictionResolved(uint256 indexed predictionId, uint256 accuracy, address predictor);
    event ReputationUpdated(address indexed user, uint256 newScore);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyVerifiedReporter() {
        require(verifiedReporters[msg.sender], "Only verified reporters can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        verifiedReporters[msg.sender] = true;
        reputationScores[msg.sender] = 1000;
    }
    
    /**
     * @dev Core Function 1: Record rainfall data
     * @param _rainfall Rainfall amount in millimeters (scaled by 100)
     * @param _location Location where rainfall was measured
     */
    function recordRainfall(uint256 _rainfall, string memory _location) external onlyVerifiedReporter {
        require(_rainfall <= 100000, "Invalid rainfall amount"); // Max 1000mm
        require(bytes(_location).length > 0, "Location cannot be empty");
        
        dataCount++;
        rainfallRecords[dataCount] = RainfallData({
            timestamp: block.timestamp,
            rainfall: _rainfall,
            location: _location,
            reporter: msg.sender,
            verified: false
        });
        
        emit RainfallRecorded(dataCount, _location, _rainfall, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Make weather predictions
     * @param _predictedRainfall Predicted rainfall amount in millimeters (scaled by 100)
     * @param _location Location for the prediction
     */
    function makePrediction(uint256 _predictedRainfall, string memory _location) external payable {
        require(msg.value >= PREDICTION_STAKE, "Insufficient stake amount");
        require(_predictedRainfall <= 100000, "Invalid rainfall prediction"); // Max 1000mm
        require(bytes(_location).length > 0, "Location cannot be empty");
        
        predictionCount++;
        predictions[predictionCount] = WeatherPrediction({
            predictionId: predictionCount,
            timestamp: block.timestamp,
            predictedRainfall: _predictedRainfall,
            location: _location,
            predictor: msg.sender,
            accuracy: 0,
            resolved: false
        });
        
        emit PredictionMade(predictionCount, _location, _predictedRainfall, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Verify rainfall data and resolve predictions
     * @param _dataId ID of the rainfall data to verify
     * @param _predictionId ID of the prediction to resolve (0 if none)
     */
    function verifyAndResolve(uint256 _dataId, uint256 _predictionId) external onlyOwner {
        require(_dataId <= dataCount && _dataId > 0, "Invalid data ID");
        require(!rainfallRecords[_dataId].verified, "Data already verified");
        
        // Verify the rainfall data
        rainfallRecords[_dataId].verified = true;
        
        // Reward the reporter
        address reporter = rainfallRecords[_dataId].reporter;
        reputationScores[reporter] += 10;
        payable(reporter).transfer(VERIFICATION_REWARD);
        
        emit DataVerified(_dataId, msg.sender);
        emit ReputationUpdated(reporter, reputationScores[reporter]);
        
        // Resolve prediction if provided
        if (_predictionId > 0 && _predictionId <= predictionCount) {
            WeatherPrediction storage prediction = predictions[_predictionId];
            
            if (!prediction.resolved && 
                keccak256(abi.encodePacked(prediction.location)) == keccak256(abi.encodePacked(rainfallRecords[_dataId].location))) {
                
                // Calculate accuracy
                uint256 actualRainfall = rainfallRecords[_dataId].rainfall;
                uint256 predictedRainfall = prediction.predictedRainfall;
                
                uint256 difference = actualRainfall > predictedRainfall ? 
                    actualRainfall - predictedRainfall : 
                    predictedRainfall - actualRainfall;
                
                // Accuracy calculation: 100% - (difference/actual * 100%)
                uint256 accuracy = actualRainfall > 0 ? 
                    (10000 - (difference * 10000) / actualRainfall) : 10000;
                
                if (accuracy > 10000) accuracy = 0; // Cap at 100%
                
                prediction.accuracy = accuracy;
                prediction.resolved = true;
                
                // Reward based on accuracy
                if (accuracy >= 8000) { // 80% or higher accuracy
                    uint256 reward = (PREDICTION_STAKE * accuracy) / 10000 + PREDICTION_STAKE;
                    reputationScores[prediction.predictor] += accuracy / 100;
                    payable(prediction.predictor).transfer(reward);
                } else if (accuracy >= 5000) { // 50% or higher accuracy
                    reputationScores[prediction.predictor] += accuracy / 200;
                    payable(prediction.predictor).transfer(PREDICTION_STAKE);
                }
                
                emit PredictionResolved(_predictionId, accuracy, prediction.predictor);
                emit ReputationUpdated(prediction.predictor, reputationScores[prediction.predictor]);
            }
        }
    }
    
    // Additional utility functions
    function addVerifiedReporter(address _reporter) external onlyOwner {
        verifiedReporters[_reporter] = true;
        reputationScores[_reporter] = 100;
    }
    
    function removeVerifiedReporter(address _reporter) external onlyOwner {
        verifiedReporters[_reporter] = false;
    }
    
    function getRainfallData(uint256 _dataId) external view returns (RainfallData memory) {
        require(_dataId <= dataCount && _dataId > 0, "Invalid data ID");
        return rainfallRecords[_dataId];
    }
    
    function getPrediction(uint256 _predictionId) external view returns (WeatherPrediction memory) {
        require(_predictionId <= predictionCount && _predictionId > 0, "Invalid prediction ID");
        return predictions[_predictionId];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Emergency withdrawal function
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}
