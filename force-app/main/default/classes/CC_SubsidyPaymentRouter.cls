public with sharing class CC_SubsidyPaymentRouter {
    
    public static Date archiveThreshold = Date.today().addMonths(-12);
    
    public class InputWrapper{
        @InvocableVariable(label = 'List of Payment Requests' description='Pass all identified payment requests here at once.')
        public List<PaymentRequest> payReqList;
        
    }

    public class PaymentRequest{
        @InvocableVariable(label = 'Provider Id' required=true)
        public String pId;
        @InvocableVariable(label = 'Pay Period' required=true)
        public Date payPeriod;
    }
    
    public class OutputWrapper{
        @InvocableVariable(label = 'List of Payment Responses' description='display all identified payment response at once.')
        //public List<PaymentResponse> payResList;
        public String finalTableOutput;
    }
    
    public class PaymentResponse{
        @InvocableVariable(label ='Payment Details')
        public String paymentDetails;
        @InvocableVariable(label ='Source')
        public String invoiceSource;
    }
    
    @InvocableMethod(label='CC Payment Router' description = 'Retrieves multiple payment details at once for a list of provider IDs and dates.')
    //public static List<PaymentResponse> handlePaymentInqueries(List<PaymentRequest> payReqList){ 
    public static List<outputWrapper> handlePaymentInqueries(List<inputWrapper> inpList){
        outputWrapper outWrap = new outputWrapper();
        outWrap.finalTableOutput ='';
        try{
            List<PaymentRequest> payReqList = new List<PaymentRequest>();
            for(inputWrapper inp : inpList){
                payReqList.addAll(inp.payReqList);
            }
            List<PaymentResponse> results =new List<PaymentResponse>();
            Set<String> providerIdSetDMO = new Set<String>();
            Set<String> providerIdSetLive = new Set<String>();
            Set<Date> payPeriodSet = new Set<Date>();
            Map<String,Invoice__c> invoiceMapLive = new Map<String,Invoice__c>();
            Map<String,Invoice_c_Home__dlm> invoiceMapDMO = new Map<String,Invoice_c_Home__dlm>();
            for(PaymentRequest payReq : payReqList){
                payPeriodSet.add(payReq.payPeriod);
                if(payReq.payPeriod <= archiveThreshold){
                    providerIdSetDMO.add(payReq.pId.toUpperCase());
                }else{
                    providerIdSetLive.add(payReq.pId.toUpperCase());
                }
            }
            for(Invoice__c inv :[SELECT Id,Invoice_Amount__c,Provider_Id__c,Pay_Period__c FROM Invoice__c 
                                 WHERE Provider_Id__c IN :providerIdSetLive
                                 AND Pay_Period__c IN :payPeriodSet]){
                                     String invKey = inv.Provider_Id__c + String.valueOf(inv.Pay_Period__c);
                                     invoiceMapLive.put(invKey,inv);
                                 }
            
            for(Invoice_c_Home__dlm dmoInv : [SELECT Id, Invoice_Amount_c__c, Provider_Id_c__c, Pay_Period_c__c FROM Invoice_c_Home__dlm
                                              WHERE Provider_Id_c__c IN :providerIdSetDMO
                                              AND Pay_Period_c__c IN :payPeriodSet]){
                                                  String invDMOKey = dmoInv.Provider_Id_c__c + String.valueOf(dmoInv.Pay_Period_c__c);
                                                  invoiceMapDMO.put(invDMOKey,dmoInv);        
                                              }
            
            for(PaymentRequest payReq : payReqList){
                String invKey = payReq.pid.toUpperCase() + String.valueOf(payReq.payPeriod);
                PaymentResponse resp = new PaymentResponse();
                if(invoiceMapDMO.containsKey(invKey)){
                    Invoice_c_Home__dlm invDMO = invoiceMapDMO.get(invKey);
                    resp.paymentDetails = 'Provider Id: '+invDMO.Provider_Id_c__c+ ' Pay Period: '+invDMO.Pay_Period_c__c+' Invoice Amount: $'+invDMO.Invoice_Amount_c__c +' Source: Archival Record';
                    
                }else if(invoiceMapLive.containsKey(invKey)){
                    Invoice__c inv= invoiceMapLive.get(invKey);
                    resp.paymentDetails = 'Provider Id: '+inv.Provider_Id__c+ ' Pay Period: '+inv.Pay_Period__c+' Invoice Amount: $'+inv.Invoice_Amount__c+' Source: Live Record';
                    
                }else{
                    resp.paymentDetails = 'Provider Id: ' + payReq.pId.toUpperCase() + ' Pay Period: ' + payReq.payPeriod + ' SOURCE: NOT_FOUND - No record exists for this provider and period.';
                }
                
                
                results.add(resp);
            }
            
            try{
                ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                
                ConnectApi.WrappedValue wrappedRawData = new ConnectApi.WrappedValue();
                wrappedRawData.value = JSON.serialize(results);
                
                promptInput.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Raw_Data' => wrappedRawData };
                promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
                promptInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
                promptInput.isPreview = false;
                
                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation promptResponse = 
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Maryland_Subsidy_Summarizer', promptInput);
                
                if (promptResponse != null && promptResponse.generations != null) {
                    outWrap.finalTableOutput = promptResponse.generations[0].text;
                } else {
                    outWrap.finalTableOutput = 'The AI was unable to summarize the data. Raw facts: ' + JSON.serialize(results);
                }
            }Catch(ConnectApi.ConnectApiException ex){
                outWrap.finalTableOutput = 'The AI was unable to summarize the data. Raw facts: ' + JSON.serialize(results);
            }
        }Catch(Exception ex){
            outWrap.finalTableOutput ='An Error Occured. Will Transfer To Human';
        }
        
        return new List<outputWrapper>{outWrap};
    }
    
}