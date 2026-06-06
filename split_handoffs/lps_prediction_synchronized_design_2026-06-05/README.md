# Prediction-Synchronized LPS Design

This directory contains the first design/specification document for
prediction-synchronized local polynomial smoothing.

Primary source:

- `lps_prediction_synchronized_design.tex`

Compiled report:

- `lps_prediction_synchronized_design.pdf`

The proposed first synchronization term penalizes disagreement between local
polynomial chart predictions on shared overlap points.  The recommended first
overlap weight is the pair-normalized product of the two ordinary chart kernel
weights,

\[
\omega_{i\ell r}
=
|O_{i\ell}|
\frac{w_{ir}w_{\ell r}}
{\sum_{s\in O_{i\ell}} w_{is}w_{\ell s}+\epsilon}.
\]

This preserves the natural interpretation that agreement matters most in the
middle of the overlap while keeping the synchronization scale comparable across
chart pairs and kernels.
