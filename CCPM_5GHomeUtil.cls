/***
*@name          CCPM_5GHomeUtil
*@author        Devesh Murdiya (Deloitte)
*@date          06/04/2019
*@description   This is a Utility class for 5G Home Webservice 
Modification    Log:
------------------------------------------------------------------------------------
Developer                          Date         Description
------------------------------------------------------------------------------------
Devesh Murdiya (Deloitte)        06/04/2019   Initial Implementation.
*/
global without sharing class CCPM_5GHomeUtil {
/**
@author        Devesh Murdiya (Deloitte)
@description   This method get called to run the Customer 5G home lead from webservice CCPM_webserviceAccLeads
@param         String,String JSON Request
@return        CCPM_webServiceUtil.responseWrapper
*/    
    public CCPM_webServiceUtil.responseWrapper getRequestJSON(String strJSONBody, String strRequestTypeHeader){
        /*Local Variables*/
        CCPM_webServiceUtil objWebUtil = new CCPM_webServiceUtil();
        Map<String, Object> mapJSONRequestBody = new Map<String, Object>();
        Map<String, Object> mapLeadDetails = new Map<String, Object>(); 
        Map<String, Object> mapAccountDetails = new Map<String, Object>();
        String strAccountUniqueIDValue = null;
        Map<String,String> mapAcccountQueryResult = new Map<String,String>();
        Map<String,Map<String, Object>> mapMapRecordSet = new Map<String,Map<String, Object>>();
        CCPM_webServiceUtil.responseWrapper responseJSON = new CCPM_webServiceUtil.responseWrapper();
        CCPM_webServiceUtil.WrapperForSObjectResponseToUtility objProcessRecords = new CCPM_webServiceUtil.WrapperForSObjectResponseToUtility();        
        /*Local Variables*/
        /*Parsing the JSON Service Request*/
        mapJSONRequestBody = objWebUtil.parseJSONRequest(strJSONBody); 
        /*Parsing the map into Account lead set packet*/
        mapMapRecordSet = parseAccLeadSet(mapJSONRequestBody);
        /*Validate if any Account lead combination is missing*/
        responseJSON = validation(mapMapRecordSet);                
        /*Get the Account number of all account records and look into salesforce*/
        if(String.IsBlank(responseJSON.errormessage)){
            /*Get Account Number from Request*/
            Set<String> setstrAccNumber = objWebUtil.parseAccountNumber(mapMapRecordSet,Label.CCPM_account,Label.CCPM_accountnumber);          
            /*Query and get all the account record*/
            if(!setstrAccNumber.isEmpty()){
                mapAcccountQueryResult = objWebUtil.findAccounts(setstrAccNumber);
                Map<String,Map<String, Object>> mapMapFinalRecordSet = populateAccUniqueId(mapMapRecordSet,mapAcccountQueryResult);                
                if(!mapMapFinalRecordSet.isEmpty()){
                    objProcessRecords = objWebUtil.processJSONPackets(mapMapFinalRecordSet,strRequestTypeHeader,null);                   
                    responseJSON = finalDMLAccLead(objProcessRecords);
                }
                  
            }
        }
        return responseJSON;    
    }
/**
@author        Devesh Murdiya (Deloitte)
@description   This method will convert the String request into Key value pair of records.
@param         Map<String, Object>
@return        Map<String,Map<String, Object>>
*/  
    public Map<String,Map<String, Object>> parseAccLeadSet(Map<String, Object> mapJSONRequestBody){     
        Map<String,Map<String, Object>> mapMapRecordSet = new Map<String,Map<String, Object>>();
        for(String strMTN : mapJSONRequestBody.keyset()){
            Map<String, Object> mapChild =  (Map<String, Object>)mapJSONRequestBody.get(strMTN);          
            mapMapRecordSet.put(strMTN,mapChild);         
        }
        return mapMapRecordSet;
    }
/**
@author        Devesh Murdiya (Deloitte)
@description   This method will validate if the Json request Packet contains the Account lead records in pair.
@param         Map<String,Map<String, Object>>
@return        CCPM_webServiceUtil.responseWrapper
*/  
    public CCPM_webServiceUtil.responseWrapper validation(Map<String,Map<String, Object>> mapMapRecordSet){
        CCPM_webServiceUtil.responseWrapper responseJSON = new CCPM_webServiceUtil.responseWrapper();
        CCPM_webServiceUtil objWebUtil = new CCPM_webServiceUtil();
        for(String strMTN : mapMapRecordSet.keyset()){
            responseJSON = objWebUtil.getValidationRule(mapMapRecordSet.get(strMTN), new Set<String>{Label.CCPM_account,Label.CCPM_lead});            
            if(String.IsNotBlank(responseJSON.errormessage)){
                break;
            }   
        }
        return responseJSON;
    }
/**
@author        Devesh Murdiya (Deloitte)
@description   This method will Populate the Accountunique Id in JSON packet if exist or not exist.
@param         Map<String,Map<String, Object>>
@return        Set<String>
*/  
    public Map<String,Map<String, Object>> populateAccUniqueId(Map<String,Map<String, Object>> mapMapRecordSet,Map<String,String> mapAcccountQueryResult){
        Map<String,Map<String, Object>> mapMapFinalRecordSet = new Map<String,Map<String, Object>>();
        for(String strMtn : mapMapRecordSet.keyset()){
            Map<String, Object> mapChildRecords = new Map<String, Object>();
            
            Map<String, Object> mapAccountRecord = mapMapRecordSet.get(strMtn);         
            Map<String, Object> mapAccountDetails = (Map<String, Object>)mapAccountRecord.get(Label.CCPM_account);
            Map<String, Object> mapLeadRecord = mapMapRecordSet.get(strMtn);            
            Map<String, Object> mapLeadDetails = (Map<String, Object>)mapAccountRecord.get(Label.CCPM_lead);
            /*Populate Account Unique Id in Account and lead packet if Account not found in SFDC*/
            if(!mapAcccountQueryResult.containsKey(string.valueof(mapAccountDetails.get(Label.CCPM_accountnumber)))){
                /*Generate the Account Unique Id in case of account not available in SFDC*/
                object objacc = CCPM_EncryptKey.CCPM_EncryptKey(string.valueof(mapAccountDetails.get(Label.CCPM_accountnumber)) + string.valueof(mapLeadDetails.get(Label.CCPM_mTNnumber)));
                object objAccMtn =  strMtn;
                object objAccEmail =  mapLeadDetails.get(Label.CCPM_email);
                mapAccountDetails.put(Label.CCPM_accountuniqueid,objacc);
                mapAccountDetails.put(Label.CCPM_mTNnumber,objAccMtn);
                mapAccountDetails.put(Label.CCPM_email,objAccEmail);
                mapLeadDetails.put(Label.CCPM_accountuniqueid,objacc);
                object objmapAcc = mapAccountDetails;
                object objmapLead = mapLeadDetails;
                mapChildRecords.put(Label.CCPM_account,objmapAcc);
                mapChildRecords.put(Label.CCPM_lead,objmapLead);
            }
            /*Populate Account Unique Id in Account and lead packet if Account found in SFDC*/
            else {
                object objacc = mapAcccountQueryResult.get(string.valueof(mapAccountDetails.get(Label.CCPM_accountnumber)));             
                mapLeadDetails.put(Label.CCPM_accountuniqueid,objacc);
                object objmapAcc = mapAccountDetails;
                object objmapLead = mapLeadDetails;
                mapChildRecords.put(Label.CCPM_account,objmapAcc);
                mapChildRecords.put(Label.CCPM_lead,objmapLead);
            }
            mapMapFinalRecordSet.put(strMtn,mapChildRecords);   
        }
        return mapMapFinalRecordSet;
    }
/**
@author        Devesh Murdiya (Deloitte)
@description   This method will Create the Account and Lead record.
@param         CCPM_webServiceUtil.WrapperForSObjectResponseToUtility
@return        CCPM_webServiceUtil.responseWrapper
*/  
    public CCPM_webServiceUtil.responseWrapper finalDMLAccLead(CCPM_webServiceUtil.WrapperForSObjectResponseToUtility objProcessRecords){
        CCPM_webServiceUtil objWebUtil = new CCPM_webServiceUtil();
        CCPM_webServiceUtil.responseWrapper responseJSON = new CCPM_webServiceUtil.responseWrapper();
        boolean boolAccErr = true;
        boolean boolLeadErr = true;
        /*Setting up save point to ensure if any DML operation failed then rollback till this point*/
        Savepoint sp = Database.setSavepoint();
        if(String.IsBlank(objProcessRecords.strErroredKey) && String.IsBlank(objProcessRecords.strErroredItem)){
            /*Create Account Records*/
            if(objProcessRecords.lstGenericObjectAccountType!=null){
                try{
                    List<Account> lstNewAccount = (List<Account>)objProcessRecords.lstGenericObjectAccountType;
                    //Begin of changes -- DITSCE-7556 -- Mythili
                    Map<String,Map<String,List<Lead>>> accUniqIdLeadMap = new Map<String,Map<String,List<Lead>>>();
                    if(objProcessRecords.lstGenericObjectLeadType!=null && objProcessRecords.lstGenericObjectLeadType.size()>0){
                        List<Lead> leadRecsList = (List<Lead>)objProcessRecords.lstGenericObjectLeadType;
                        for(Lead leadObj : leadRecsList){
                            String leadType;
                            if(leadObj.LeadSource.containsIgnoreCase(Label.CCPM_Indirect)){
                                leadType = Label.CCPM_Indirect;
                            }else{
                                leadType = Label.CCPM_Direct;
                            }
                            if(String.isNotBlank(leadObj.CCPM_accountUniqueID__c)){
                                if(!accUniqIdLeadMap.containsKey(leadObj.CCPM_accountUniqueID__c)){
                                    accUniqIdLeadMap.put(leadObj.CCPM_accountUniqueID__c,new Map<String,List<Lead>>());
                                    if(!accUniqIdLeadMap.get(leadObj.CCPM_accountUniqueID__c).containsKey(leadType)){
                                        accUniqIdLeadMap.get(leadObj.CCPM_accountUniqueID__c).put(leadType,new List<Lead>());
                                    }
                                }else if(!accUniqIdLeadMap.get(leadObj.CCPM_accountUniqueID__c).containsKey(leadType)){
                                    accUniqIdLeadMap.get(leadObj.CCPM_accountUniqueID__c).put(leadType,new List<Lead>());
                                }
                                accUniqIdLeadMap.get(leadObj.CCPM_accountUniqueID__c).get(leadType).add(leadObj);
                            }
                        }
                    }

                    if(accUniqIdLeadMap!=null && accUniqIdLeadMap.size()>0 && lstNewAccount.size()>0){
                        for(Account accObj : lstNewAccount){
                            Map<String,List<Lead>> leadMap = accUniqIdLeadMap.get(accObj.CCPM_accountUniqueID__c);
                            if(leadMap.containsKey(Label.CCPM_Indirect)){
                                accObj.CCPM_indirectStoreID__c = accObj.CCPM_storeID__c;
                            }
                            if(!leadMap.containsKey(Label.CCPM_Direct)){
                                accObj.CCPM_storeID__c = null;
                            }
                        }
                    }
                    //End of Changes -- DITSCE-7556 -- Mythili
                    insert lstNewAccount;
                    boolAccErr = false;
                }
                catch(DMLException e){                  
                    responseJSON.errormessage = Label.CCPM_errDMLAccount;
                    responseJSON.statuscode = Label.CCPM_errStatusCode;
                }   
            }
            else{
                boolAccErr = false;
            }   
            /*Create Lead records*/
            if(objProcessRecords.lstGenericObjectLeadType!=null && !boolAccErr){
                try{
                    //Made changes -- passed null for record type and lead type labels -- DITSCE-7153 -- Mythili
                    List<Lead> lstNewLead = objWebUtil.populateLeadFields((List<Lead>)objProcessRecords.lstGenericObjectLeadType,null,Label.CCPM_customer5GHome);                    
                    insert lstNewLead;
                    boolLeadErr = false;
                }
                catch(DMLException e){
                    system.debug('Error:'+e.getmessage());
                    Database.rollback(sp);
                    responseJSON.errormessage = Label.CCPM_errDMLLead;
                    responseJSON.statuscode = Label.CCPM_errStatusCode;
                }
            }
            if(!boolAccErr && !boolLeadErr){
                responseJSON.errormessage = null;
                responseJSON.statuscode = Label.CCPM_successStatusCode;
            }
        }
        else{
            responseJSON.errormessage = 'Field '+objProcessRecords.strErroredItem+ ' for MTN '+ objProcessRecords.strErroredKey+ ' is Required and Missing in Request';
            responseJSON.statuscode = Label.CCPM_errStatusCode;
        }
        return responseJSON;
    }
}