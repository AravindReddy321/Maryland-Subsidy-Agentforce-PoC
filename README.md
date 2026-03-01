# Technical Documentation: Maryland Child Care Subsidy Agentforce PoC

## Project Overview
This repository contains the source metadata and logic for an Autonomous AI Agent designed to modernize the Maryland State Child Care Agency’s provider inquiry system. The solution leverages Salesforce Agentforce and Data Cloud to provide a unified interface for current and historical subsidy payment data.

<img width="1470" height="925" alt="image" src="https://github.com/user-attachments/assets/abab0c9c-b9f4-4b8e-a838-6ca25a39bb99" />


---

## Technical Architecture
The system implements a multi-tier data retrieval strategy to balance performance with massive data scale:

* **Tier 1 (Salesforce Core):** High-frequency access for payment records from the current and previous fiscal years.
* **Tier 2 (Salesforce Data Cloud):** Long-term archival access for historical records stored as Data Model Objects (DMOs), enabling a searchable audit trail for legacy payment data.
* **Bulkified Execution:** The CC_SubsidyPaymentRouter is architected to handle record collections in a single transaction, ensuring the solution remains within Salesforce governor limits during high-volume inquiries.
* **Deterministic Grounding:** Utilizes the Maryland_Subsidy_Summarizer (Prompt Template) to map raw data into a structured Markdown table, ensuring the LLM maintains 100% data integrity without hallucination.

<img width="1470" height="927" alt="image" src="https://github.com/user-attachments/assets/bfc74618-bed6-46c7-9c66-38bd2919c3d7" />


---

## End-to-End Data Flow

<ol>
<li><strong>Ingress: Omni-Channel Routing</strong><br>
  
The user query enters via the <strong>Experience Cloud</strong> chat widget. The <code>Route_To_Maryland_Agent_Flow</code> (Omni-Channel Flow) acts as the initial entry point, establishing the session context and routing the incoming request directly to the <strong>Subsidy Support Agent</strong> (Agentforce).</li>

<li><strong>Reasoning: ReAct Engine Orchestration</strong>
  
The <code>Subsidy_Support_Agent</code> (GenAiPlanner) utilizes the ReAct (Reasoning and Acting) framework to analyze user intent. Upon identifying a "Payment Inquiry," the agent autonomously extracts required entities (slots): <strong>Provider ID</strong>, <strong>Month</strong>, and <strong>Year</strong>.</li>

<li><strong>Action Execution: Hybrid Apex Router</strong>
  
The Agent invokes the <code>CC_SubsidyPaymentRouter</code> class. This logic layer determines the data residency:
<ul>
  <li><strong>Current Tier:</strong> Queries live <strong>Salesforce Core Objects</strong>.</li>
  <li><strong>Historical Tier:</strong> Routes queries for archived records to <strong>Data Cloud DMOs</strong>. For this PoC, invoices older than one year are queried from the DMO.</li>
</ul>
</li><br>

<li><strong>Grounding: GenAI Prompt Templates</strong>
  
Raw data from the Apex router is passed into a <code>Maryland_Subsidy_Summarizer</code> (GenAiPromptTemplate) for final processing. This layer performs <strong>Data Transformation</strong>: it classifies records into "Hot" or "Cold" tiers based on the source metadata, filters out missing records, and structures the final response into a professional Markdown table for the provider.</li>

<li><strong>Egress: Structured Provider Response</strong>
  
The final, human-readable response is delivered back to the chat interface. By utilizing the structured Markdown table generated in the previous step, the system ensures that complex subsidy data is presented to the provider in a clear, consistent, and professional format.</li>
</ol>

---

## Core Components and Metadata
* **Orchestration Engine:** Configured via Subsidy_Support_Agent (GenAiPlanner) to manage user intent and autonomous decision-making.
* **Apex Logic Layer:** The `CC_SubsidyPaymentRouter` class serves as the primary Invocable Method, executing conditional routing between Core and Data Cloud based on the 'Payment Year' parameter.
* **Data Transformation Layer:** Utilizes the Maryland_Subsidy_Summarizer (GenAiPromptTemplate) to classify records into Hot/Cold tiers and structure the final Markdown table.
* **Security Framework:** The solution utilizes Class-Level Authorization. The Agent is explicitly granted access to the CC_SubsidyPaymentRouter controller. Data retrieval is governed by Apex using with sharing keywords, ensuring that record visibility is strictly enforced by the sharing rules and permissions assigned to the Agent's execution identity
* **Interface Layer:** Hosted on the Maryland Provider Portal (Experience Cloud) utilizing the Route_To_Maryland_Agent_Flow to provide a public-facing, guest-access-enabled chat interface.

---

## Business Logic and Grounding Strategy
To maintain agency compliance and data accuracy, the following grounding rules have been enforced within the Agent’s instructions:

1. **Input Validation:** The Agent is programmed to recognize and redirect non-functional inputs (e.g., gibberish or vague greetings) back to the subsidy inquiry workflow.
2. **Payment Cycle Enforcement:** Intelligence is applied to ensure users are guided toward "1st of the month" payment logic, consistent with Maryland state policy.
3. **Temporal Constraints:** The system proactively blocks queries for future dates (e.g., 2027+) where data has not yet been generated.
4. **Architectural Bulkification:** The Apex layer is designed to handle bulk requests. By utilizing List<PaymentRequest> and List<PaymentResponse>, the logic can process multiple Provider IDs in a single transaction, optimizing Governor Limit consumption and ensuring the Agent stays responsive under high-concurrency loads.

---

## Functional Validation and Testing
The Proof of Concept can be verified using the following parameters on the https://orgfarm-5bd59c15fa-dev-ed.develop.my.site.com/:

| Test Case | ID / Month / Year | Expected Result |
| :--- | :--- | :--- |
| **Historical Retrieval** | P-200 / January / 2025 | Success via Data Cloud Path |
| **Current Retrieval** | P-100 / January / 2026 | Success via Salesforce Core Path |
| **Bulk Retrieval** | P-100 / January / 2026 <br> P-100 / December / 2025 <br> P-200 / January / 2025 |  Success via Hybrid Routing (Core + DMO) |
| **Boundary Violation** | P-100 / January / 2030 | Logical Refusal (Grounding) |
| **Input Steering** | "ssss" | Re-alignment to Payment Topic |

---

## Repository Structure
* **Apex Logic:** `force-app/main/default/classes/`
* **AI Metadata:** `force-app/main/default/genAiPlanners/`, `force-app/main/default/genAiPlannerBundles/`
* **Portal Configuration:** `force-app/main/default/messagingChannels/`, `force-app/main/default/experienceBundles/`, `force-app/main/default/embeddedServiceConfig/`

---

 ## Known Constraint & Scalability Roadmap.
 Currently, the Agent is optimized for Targeted Queries (specific providers/dates). For massive historical data export, the system will be designed to trigger a Data Export rather than a Real-time Chat Summary to respect LLM Token limits and ensure UI responsiveness.
 
 **Example Prompt for Scalability Issue:** 
 
give subsidy payment details of all providers with provider id p-100 to p-200 for months starting from january to decemebr of years 2020,2021,2022,2023,2024,2025,2026
