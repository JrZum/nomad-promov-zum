
import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";

c
  
onst Index = () => {
  const navigate = useNavigate();
  
  useEffect(() => {
    // Redirecionar para a página de login do administrador
    navigate("/admin");
  }, [navigate]);
  
  return (
    <div className="container mx-auto p-6 flex items-center justify-center min-h-screen">
      <p>Redirecionando...</p>
    </div>
  );
};

export default Index;
