# Agent Ranking Model – Astra Space Travel Challenge 🚀

## Overview

This project implements a real-time SQL-based ranking system for matching prospective space travel customers with the most suitable travel agents at Astra Luxury Travel.

### Business Objective

Astra offers high-end travel experiences across the solar system. When a new customer inquiry comes in, the Enterprise Intelligence team must assign an agent who is most likely to convert the lead and maximize customer satisfaction and revenue. This project builds a scoring model to power that assignment process.

---

## Inputs

At the time of assignment, the following details are available for each new customer:

- Customer Name
- Communication Method
- Lead Source
- Destination
- Launch Location 

---

## Model Approach

The model ranks all available agents using a composite scoring formula based on:

### 1. **Overall Performance Metrics**
| Metric | Description |
|--------|-------------|
| Average Customer Rating | Agent's historic average rating (out of 5) |
| Conversion Rate | Confirmed bookings ÷ total assignments |
| Average Revenue Per Booking | For confirmed bookings only |
| Years of Service | Tenure at the company |

### 2. **Contextual Familiarity**
| Metric | Description |
|--------|-------------|
| CommConversionRate | Agent’s success rate with this communication method |
| LeadConversionRate | Agent’s success rate with this lead source |
| DestinationAvgRevenue | Average revenue this agent has generated for this destination |
| LaunchConversionRate | Conversion rate for this launch location |

If no contextual data is available for a given field, the model falls back to the agent’s global conversion/revenue performance.

### 3. **Returning Customers**
If a customer has previously worked with an agent and had a successful (confirmed) booking, they are automatically matched with that same agent again. This honors agent-customer familiarity when prior experience was positive.

---

## Output

The output is a **stack-ranked list** of all travel agents, each with a `Score` on a 0–1 scale. The top-ranked agent is the best match for the current customer query.

---

## SQL Components

### ✅ View Creation
- A `VIEW` called `agent_summary` aggregates performance metrics for each agent across bookings.

### ✅ Ranking Logic
- A query (or optionally a stored procedure) scores agents based on both overall and contextual features.

### ✅ Files
| File | Description |
|------|-------------|
| `agent_ranking_model.sql` | Full SQL implementation of the model |
| `assignment_history SQL Table.txt` | Table DDL & sample data for assignment history |
| `bookings SQL Table.txt` | Table DDL & sample data for bookings |
| `space_travel_agents SQL Table.txt` | Table DDL & sample data for agents |
| `AmeriSave - SQL Model.ipynb` | Optional Python notebook with DuckDB implementation |

---

## Notes

- The model is designed for real-time scoring and does **not** rely on any external ML libraries.
- The design prioritizes transparency, simplicity, and easy adaptation for changing business logic.

---

## Author

**Michael Walker**  
Built as part of the AmeriSave Space Travel Challenge – August 2025  
[GitHub: MSVWalker](https://github.com/MSVWalker)

---