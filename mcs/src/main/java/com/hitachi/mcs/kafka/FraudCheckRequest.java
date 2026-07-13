package com.hitachi.mcs.kafka;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Request body sent to the ML service's POST /predict/fraud endpoint.
 * JSON field names (snake_case) match the Python FastAPI Pydantic model
 * exactly via @JsonProperty, since Java conventionally uses camelCase.
 */
public class FraudCheckRequest {

    @JsonProperty("amount")
    private double amount;

    @JsonProperty("hour_of_day")
    private int hourOfDay;

    @JsonProperty("customer_txn_count_24h")
    private long customerTxnCount24h;

    @JsonProperty("merchant_avg_amount")
    private double merchantAvgAmount;

    public FraudCheckRequest() {}

    public FraudCheckRequest(double amount, int hourOfDay, long customerTxnCount24h, double merchantAvgAmount) {
        this.amount = amount;
        this.hourOfDay = hourOfDay;
        this.customerTxnCount24h = customerTxnCount24h;
        this.merchantAvgAmount = merchantAvgAmount;
    }

    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }

    public int getHourOfDay() { return hourOfDay; }
    public void setHourOfDay(int hourOfDay) { this.hourOfDay = hourOfDay; }

    public long getCustomerTxnCount24h() { return customerTxnCount24h; }
    public void setCustomerTxnCount24h(long customerTxnCount24h) { this.customerTxnCount24h = customerTxnCount24h; }

    public double getMerchantAvgAmount() { return merchantAvgAmount; }
    public void setMerchantAvgAmount(double merchantAvgAmount) { this.merchantAvgAmount = merchantAvgAmount; }
}